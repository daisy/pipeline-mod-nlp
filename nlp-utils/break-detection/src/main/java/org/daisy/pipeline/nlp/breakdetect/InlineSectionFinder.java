package org.daisy.pipeline.nlp.breakdetect;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

import net.sf.saxon.s9api.Axis;
import net.sf.saxon.s9api.QName;
import net.sf.saxon.s9api.XdmNode;
import net.sf.saxon.s9api.XdmNodeKind;
import net.sf.saxon.s9api.XdmSequenceIterator;

import org.daisy.pipeline.nlp.LanguageUtils;
import org.daisy.pipeline.nlp.LanguageUtils.Language;
import org.daisy.pipeline.nlp.breakdetect.InlineSectionProcessor.Leaf;
import org.daisy.pipeline.nlp.lexing.LexService.LexerInitException;

/**
 * The InlineSectionFinder notifies an InlineSectionProcessor that a new inline
 * section has been found, whenever:
 * 
 * - A non-inline element is found, in document order ;
 * 
 * - The language changes ;
 * 
 * - An element with an ID attribute is found and if its children would belong
 * to different inline sections. It prevents the algorithm from splitting up
 * such elements.
 */
public class InlineSectionFinder {
	private FormatSpecifications mSpecs;
	private InlineSectionProcessor mProc;
	private List<Leaf> mCurrentSection;
	private List<String> mCurrentText;
	private int mCurrentSectionSize;
	private Language mCurrentLang;
	private Set<String> mUnsplittable;

	private static final QName IdAttr = new QName("id");

	public void find(XdmNode root, int rootLevel, FormatSpecifications specs,
	        InlineSectionProcessor processor, Set<String> unsplittable)
	        throws LexerInitException {

		mCurrentSection = new ArrayList<Leaf>();
		mCurrentText = new ArrayList<String>();
		mCurrentSectionSize = 0;
		mSpecs = specs;
		mProc = processor;
		mCurrentLang = null;
		mUnsplittable = unsplittable;

		findRec(root, rootLevel, null);
		mProc = null;
		mSpecs = null;
		mCurrentSection = null;
		mUnsplittable = null;
	}

	private void addToSection(XdmNode node, int level, String text) {
		if (mCurrentSectionSize == mCurrentSection.size()) {
			mCurrentSection.add(new Leaf());
			mCurrentText.add(null);
		}

		Leaf l = mCurrentSection.get(mCurrentSectionSize);
		l.formatting = node;
		l.level = level;

		mCurrentText.set(mCurrentSectionSize++, text);
	}

	private void notifyNewSection() throws LexerInitException {
		if (mCurrentSectionSize > 0) {
			int k = 0;
			for (k = 0; k < mCurrentSectionSize
			        && (mCurrentText.get(k) == null || mCurrentSection.get(k).formatting == null); ++k);
			if (k == mCurrentSectionSize) {
				mProc.onEmptySectionFound(mCurrentSection.subList(0,
				        mCurrentSectionSize));
			} else {
				mProc.onInlineSectionFound(
				        mCurrentSection.subList(0, mCurrentSectionSize),
				        mCurrentText.subList(0, mCurrentSectionSize),
				        mCurrentLang);
			}
			mCurrentSectionSize = 0;
		}
	}

	private void findRec(XdmNode node, int level, Language lang)
	        throws LexerInitException {
		if (node.getNodeKind() == XdmNodeKind.TEXT) {
			addToSection(node.getParent(), level - 1, node.getStringValue());
		} else {

			String langstr = node.getAttributeValue(mSpecs.langAttr);
			if (langstr != null) {
				Language x = LanguageUtils.stringToLanguage(langstr);
				if (x != null) {
					lang = x;
				}
			}

			if (lang != mCurrentLang) {
				notifyNewSection();
				mCurrentLang = lang;
			}

			String id = node.getAttributeValue(IdAttr);

			XdmSequenceIterator iter = node.axisIterator(Axis.CHILD);
			if (node.getNodeName() != null
			        && mSpecs.inlineElements.contains(node.getNodeName()
			                .getLocalName())
			        && (id == null || !mUnsplittable.contains(id))) {

				//*** inline element ***
				boolean isSpace = mSpecs.spaceEquivalentElements.contains(node
				        .getNodeName().getLocalName());
				if (isSpace) {
					addToSection(null, level,
					        LanguageUtils.getWhiteSpaceSymbol(lang));
				}
				if (mSpecs.commaEquivalentElements.contains(node.getNodeName()
				        .getLocalName())
				        && !LanguageUtils.getCommaLeftSymbol(lang).isEmpty()) {
					addToSection(null, level,
					        LanguageUtils.getCommaLeftSymbol(lang));
				}

				if (!iter.hasNext()) {
					//*** text-free leaf ***
					addToSection(node, level, null);
				} else {
					while (iter.hasNext()) {
						XdmNode child = (XdmNode) iter.next();
						findRec(child, level + 1, lang);
					}
				}

				if (mSpecs.commaEquivalentElements.contains(node.getNodeName()
				        .getLocalName())
				        && !LanguageUtils.getCommaRightSymbol(lang).isEmpty()) {
					addToSection(null, level,
					        LanguageUtils.getCommaRightSymbol(lang));
				}
				if (isSpace) {
					addToSection(null, level,
					        LanguageUtils.getWhiteSpaceSymbol(lang));
				}
			} else {
				notifyNewSection();
				if (!iter.hasNext()) {
					//*** text-free leaf ***
					addToSection(node, level, null);

				} else {
					//*** non-inline element ***
					while (iter.hasNext()) {
						XdmNode child = (XdmNode) iter.next();
						findRec(child, level + 1, lang);
					}
				}
				notifyNewSection();
			}
		}
	}
}