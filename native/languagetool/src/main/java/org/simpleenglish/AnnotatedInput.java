package org.simpleenglish;

import com.fasterxml.jackson.databind.JsonNode;
import org.languagetool.markup.AnnotatedText;
import org.languagetool.markup.AnnotatedTextBuilder;

final class AnnotatedInput {
  private AnnotatedInput() {}

  static AnnotatedText parse(JsonNode request) {
    JsonNode plainText = request.get("text");
    if (plainText != null && plainText.isTextual()) {
      return new AnnotatedTextBuilder().addText(plainText.asText()).build();
    }

    JsonNode annotation = request.get("annotation");
    if (annotation == null || !annotation.isArray()) {
      throw new IllegalArgumentException("request must contain text or annotation");
    }

    var builder = new AnnotatedTextBuilder();
    for (JsonNode segment : annotation) {
      JsonNode text = segment.get("text");
      if (text != null) {
        builder.addText(text.asText());
        continue;
      }

      JsonNode markup = segment.get("markup");
      if (markup == null) {
        throw new IllegalArgumentException("annotation segment must contain text or markup");
      }
      JsonNode interpretAs = segment.get("interpretAs");
      if (interpretAs == null) {
        builder.addMarkup(markup.asText());
      } else {
        builder.addMarkup(markup.asText(), interpretAs.asText());
      }
    }
    return builder.build();
  }
}
