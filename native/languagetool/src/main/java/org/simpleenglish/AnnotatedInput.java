package org.simpleenglish;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.IOException;
import org.languagetool.markup.AnnotatedText;
import org.languagetool.markup.AnnotatedTextBuilder;

final class AnnotatedInput {
  private static final ObjectMapper MAPPER = new ObjectMapper();

  private AnnotatedInput() {}

  static AnnotatedText parse(String json) throws IOException {
    JsonNode annotation = MAPPER.readTree(json).get("annotation");
    if (annotation == null || !annotation.isArray()) {
      throw new IllegalArgumentException("data must contain an annotation array");
    }

    var builder = new AnnotatedTextBuilder();
    for (JsonNode segment : annotation) {
      JsonNode text = segment.get("text");
      JsonNode markup = segment.get("markup");
      if (text != null && text.isTextual() && markup == null) {
        builder.addText(text.asText());
      } else if (markup != null && markup.isTextual() && text == null) {
        JsonNode interpretAs = segment.get("interpretAs");
        if (interpretAs == null) {
          builder.addMarkup(markup.asText());
        } else if (interpretAs.isTextual()) {
          builder.addMarkup(markup.asText(), interpretAs.asText());
        } else {
          throw new IllegalArgumentException("interpretAs must be a string");
        }
      } else {
        throw new IllegalArgumentException("annotation entry must contain exactly one text or markup string");
      }
    }
    return builder.build();
  }
}
