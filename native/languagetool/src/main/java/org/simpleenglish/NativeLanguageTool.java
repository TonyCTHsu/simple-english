package org.simpleenglish;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.nio.charset.StandardCharsets;
import java.util.List;
import org.languagetool.JLanguageTool;
import org.languagetool.markup.AnnotatedText;
import org.languagetool.rules.Rule;
import org.languagetool.rules.RuleMatch;
import org.languagetool.rules.patterns.AbstractPatternRule;
import org.languagetool.rules.patterns.PatternRuleLoader;

public final class NativeLanguageTool {
  private static final ObjectMapper MAPPER = new ObjectMapper();
  private final RestrictedEnglish language;
  private final JLanguageTool tool;

  private NativeLanguageTool() throws IOException {
    language = new RestrictedEnglish();
    tool = new JLanguageTool(language);
    for (Rule rule : tool.getAllRules()) {
      tool.disableRule(rule.getFullId());
    }

    try (InputStream input = NativeLanguageTool.class.getResourceAsStream("/org/simpleenglish/simple-english.xml")) {
      if (input == null) {
        throw new IOException("embedded simple-english.xml is missing");
      }
      List<AbstractPatternRule> customRules =
          new PatternRuleLoader().getRules(input, "simple-english.xml", language);
      for (AbstractPatternRule rule : customRules) {
        tool.addRule(rule);
      }
    }
  }

  public static void main(String[] args) throws Exception {
    var application = new NativeLanguageTool();
    var input = new BufferedReader(new InputStreamReader(System.in, StandardCharsets.UTF_8));
    var output = new BufferedWriter(new OutputStreamWriter(System.out, StandardCharsets.UTF_8));

    String line;
    while ((line = input.readLine()) != null) {
      ObjectNode response;
      try {
        response = application.check(MAPPER.readTree(line));
      } catch (Exception error) {
        response = MAPPER.createObjectNode();
        response.put("error", error.getMessage());
      }
      output.write(MAPPER.writeValueAsString(response));
      output.newLine();
      output.flush();
    }
  }

  private ObjectNode check(JsonNode request) throws IOException {
    AnnotatedText text = AnnotatedInput.parse(request);
    ArrayNode matches = MAPPER.createArrayNode();
    for (RuleMatch match : tool.check(text)) {
      matches.add(serialize(match, text));
    }
    ObjectNode response = MAPPER.createObjectNode();
    response.set("matches", matches);
    return response;
  }

  private ObjectNode serialize(RuleMatch match, AnnotatedText text) {
    int offset = match.getFromPos();
    int length = match.getToPos() - offset;

    ObjectNode context = MAPPER.createObjectNode();
    context.put("text", text.getTextWithMarkup().substring(offset, offset + length));
    context.put("offset", 0);
    context.put("length", length);

    ObjectNode rule = MAPPER.createObjectNode();
    rule.put("id", match.getSpecificRuleId());

    ObjectNode serialized = MAPPER.createObjectNode();
    serialized.put("message", language.toAdvancedTypography(match.getMessage()));
    serialized.put("offset", offset);
    serialized.put("length", length);
    serialized.set("context", context);
    serialized.set("rule", rule);
    return serialized;
  }
}
