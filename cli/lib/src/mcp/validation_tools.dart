import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:dashability_core/dashability_core.dart';

/// Registers validation tools on the MCP server.
void registerValidationTools(ToolsSupport server, AppiumActor actor) {
  // assert_visible
  server.registerTool(
    Tool(
      name: 'assert_visible',
      description:
          'Check if an element with the given text/ID is visible on screen.',
      inputSchema: ObjectSchema(
        required: ['text'],
        properties: {
          'text': Schema.string(
            description: 'Text or accessibility ID to check visibility for',
          ),
        },
      ),
      annotations: ToolAnnotations(readOnlyHint: true),
    ),
    (request) async {
      final text = request.arguments!['text'] as String;
      final visible = await actor.isVisible(text);

      return CallToolResult(
        content: [
          TextContent(text: jsonEncode({'visible': visible, 'target': text})),
        ],
      );
    },
  );
}
