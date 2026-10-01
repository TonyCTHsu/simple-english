package org.simpleenglish;

import java.io.IOException;
import java.util.Collections;
import java.util.List;
import java.util.ResourceBundle;
import org.languagetool.Language;
import org.languagetool.UserConfig;
import org.languagetool.language.English;
import org.languagetool.rules.Rule;
import org.languagetool.rules.patterns.AbstractPatternRule;

final class RestrictedEnglish extends English {
  @Override
  public List<Rule> getRelevantRules(ResourceBundle messages, UserConfig userConfig,
      Language motherTongue, List<Language> altLanguages) throws IOException {
    return Collections.emptyList();
  }

  @Override
  public List<String> getRuleFileNames() {
    return Collections.emptyList();
  }

  @Override
  protected synchronized List<AbstractPatternRule> getPatternRules() {
    return Collections.emptyList();
  }
}
