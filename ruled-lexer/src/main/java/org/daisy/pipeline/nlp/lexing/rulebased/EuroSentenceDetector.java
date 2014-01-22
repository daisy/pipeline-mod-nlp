package org.daisy.pipeline.nlp.lexing.rulebased;

import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.daisy.pipeline.nlp.TextCategorizer.CategorizedWord;
import org.daisy.pipeline.nlp.TextCategorizer.Category;

/**
 * Sentence detector suited for languages with sentences starting with a capital
 * letter after a white space and a stopping punctuation mark. To detect cases
 * such like 'quoted sentence. » New sentence', the algorithm tries to match
 * unigrams, bigrams and trigrams against a prioritized list of ending-sentence
 * patterns.
 */
public class EuroSentenceDetector implements ISentenceDetector {

	static public class SentencePattern {
		private Matcher[] mMatchers;
		private Category[] mCategories;
		private int mSentenceEndPos;

		public SentencePattern(int sentenceEndPos, Category... categories) {
			mCategories = categories;
			mSentenceEndPos = sentenceEndPos;

		}

		public SentencePattern regex(String... regex) {
			mMatchers = new Matcher[regex.length];
			for (int k = 0; k < mMatchers.length; ++k)
				mMatchers[k] = Pattern.compile(regex[k]).matcher("");
			return this;
		}

		public int match(List<CategorizedWord> words) {
			if (words.size() < mCategories.length)
				return -1;
			int k;
			for (k = 0; k < mCategories.length && words.get(k).category == mCategories[k]; ++k);
			if (k != mCategories.length)
				return -1;
			for (k = 0; k < mCategories.length; ++k) {
				mMatchers[k].reset(words.get(k).word);
				if (!mMatchers[k].matches())
					return -1;
			}
			return mSentenceEndPos;
		}
	}

	private List<List<CategorizedWord>> mResult;
	private int mHead;
	private int mTail;
	private int mSentenceIndex;
	private SentencePattern[] mPositivePatterns;
	private SentencePattern[] mNegativePatterns;

	public EuroSentenceDetector() {
		mResult = new ArrayList<List<CategorizedWord>>();

		//note: The patterns accept strings of any length, but for now the RuleBasedTextCategorizer
		//produces only 1-length punctuation marks.

		String delimiter = "[.:?!…]*[?!…]+[….:?!]*";

		mPositivePatterns = new SentencePattern[]{
		        new SentencePattern(0, Category.PUNCTUATION, Category.SPACE, Category.COMMON)
		                .regex("[.:]+", ".+", "[\\p{Lu}].*"),
		        new SentencePattern(1, Category.PUNCTUATION, Category.QUOTE).regex("[.?!…]+",
		                ".+"),
		        new SentencePattern(2, Category.PUNCTUATION, Category.SPACE, Category.QUOTE)
		                .regex("[.?!…]+", ".+", ".+"),
		        new SentencePattern(1, Category.PUNCTUATION, Category.PUNCTUATION).regex(
		                delimiter, ":"),
		        new SentencePattern(0, Category.PUNCTUATION).regex(delimiter)
		};

		mNegativePatterns = new SentencePattern[]{
		        new SentencePattern(0, Category.PUNCTUATION, Category.PUNCTUATION,
		                Category.PUNCTUATION, Category.PUNCTUATION, Category.PUNCTUATION)
		                .regex("\\[", ".", ".", ".", "\\]"),
		        new SentencePattern(0, Category.PUNCTUATION, Category.PUNCTUATION,
		                Category.PUNCTUATION).regex("\\[", "…", "\\]"),
		        new SentencePattern(0, Category.PUNCTUATION, Category.PUNCTUATION).regex(".*",
		                "[),]")
		};
	}

	@Override
	public List<List<CategorizedWord>> split(List<CategorizedWord> words) {
		mHead = 0;
		mTail = 0;
		mSentenceIndex = 0;

		for (int j = 0; j < words.size(); ++j) {
			addWord();
			List<CategorizedWord> right = words.subList(j, words.size());
			int i;
			int res = 0;
			for (i = 0; i < mNegativePatterns.length
			        && (res = mNegativePatterns[i].match(right)) == -1; ++i);
			if (res != -1)
				continue;
			for (i = 0; i < mPositivePatterns.length
			        && (res = mPositivePatterns[i].match(right)) == -1; ++i);

			if (res == -1)
				continue;
			for (; res > 0; --res, ++j)
				addWord();
			newSentence(words);
		}

		newSentence(words);

		return mResult.subList(0, mSentenceIndex);
	}

	private void newSentence(List<CategorizedWord> words) {
		if (mHead > mTail) {
			if (mSentenceIndex == mResult.size()) {
				mResult.add(null);
			}
			mResult.set(mSentenceIndex, words.subList(mTail, mHead));
			++mSentenceIndex;
			mTail = mHead;
		}
	}

	private void addWord() {
		++mHead;
	}
}