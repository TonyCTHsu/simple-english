package org.simpleenglish;

import java.io.FileInputStream;
import java.util.Collections;
import java.util.List;
import org.languagetool.DetectedLanguage;
import org.languagetool.JLanguageTool;
import org.languagetool.markup.AnnotatedText;
import org.languagetool.markup.AnnotatedTextBuilder;
import org.languagetool.rules.Rule;
import org.languagetool.rules.RuleMatch;
import org.languagetool.rules.patterns.AbstractPatternRule;
import org.languagetool.rules.patterns.PatternRuleLoader;
import org.languagetool.tools.RuleMatchesAsJsonSerializer;

public final class NativeLanguageTool {
  private NativeLanguageTool() {}

  public static void main(String[] args) throws Exception {
    if (args.length != 3 || !(args[1].equals("--text") || args[1].equals("--data"))) {
      System.err.println("usage: languagetool-native RULES_XML (--text TEXT | --data ANNOTATION_JSON)");
      System.exit(2);
    }

    var language = new RestrictedEnglish();
    var tool = new JLanguageTool(language);
    for (Rule rule : tool.getAllRules()) {
      tool.disableRule(rule.getFullId());
    }

    List<AbstractPatternRule> customRules;
    try (var input = new FileInputStream(args[0])) {
      customRules = new PatternRuleLoader().getRules(input, args[0], language);
    }
    for (AbstractPatternRule rule : customRules) {
      tool.addRule(rule);
    }

    AnnotatedText text = args[1].equals("--text")
        ? new AnnotatedTextBuilder().addText(args[2]).build()
        : AnnotatedInput.parse(args[2]);
    List<RuleMatch> matches = tool.check(text);
    var serializer = new RuleMatchesAsJsonSerializer(0, language);
    System.out.println(serializer.ruleMatchesToJson(
        matches, Collections.emptyList(), text, 40,
        new DetectedLanguage(language, language), null, false));
  }
}
