package org.daisy.pipeline.nlp.matchrules;

import java.io.File;
import java.io.IOException;
import java.util.List;

import org.daisy.pipeline.nlp.TextCategorizer.Category;
import org.daisy.pipeline.nlp.TextCategorizer.MatchMode;

import com.google.common.base.Charsets;
import com.google.common.io.Files;

/**
 * Match the input strings with a list of strings read from a text file.
 */
public class WordFileMatchRule extends WordListMatchRule {

    public WordFileMatchRule(Category category, int priority,
            boolean caseSensitive, MatchMode matchMode, boolean capitalSensitive) {
        super(category, priority, caseSensitive, matchMode, capitalSensitive);
    }

    void init(String filename) throws IOException {
        List<String> prefixes = Files.readLines(new File(filename),
                Charsets.UTF_8);
        super.init(prefixes);
    }

}
