import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:dashability/dashability.dart';

/// Registers Appium action tools on the MCP server.
void registerActionTools(ToolsSupport server, AppiumActor actor) {
  // tap
  server.registerTool(
    Tool(
      name: 'tap',
      description: 'Tap an element on screen by text or accessibility ID.',
      inputSchema: ObjectSchema(
        properties: {
          'text': Schema.string(description: 'Text content to find and tap'),
          'id': Schema.string(description: 'Accessibility ID to find and tap'),
        },
      ),
      annotations: ToolAnnotations(destructiveHint: false, readOnlyHint: false),
    ),
    (request) async {
      final text = request.arguments?['text'] as String?;
      final id = request.arguments?['id'] as String?;

      if (text == null && id == null) {
        return CallToolResult(
          isError: true,
          content: [TextContent(text: 'Either "text" or "id" is required.')],
        );
      }

      if (id != null) {
        await actor.tapById(id);
      } else {
        await actor.tapByText(text!);
      }

      return CallToolResult(
        content: [
          TextContent(
            text: jsonEncode({'status': 'tapped', 'target': id ?? text}),
          ),
        ],
      );
    },
  );

  // scroll
  server.registerTool(
    Tool(
      name: 'scroll',
      description: 'Scroll the screen in a direction.',
      inputSchema: ObjectSchema(
        required: ['direction'],
        properties: {
          'direction': Schema.string(
            description: 'Direction to scroll: up, down, left, right',
          ),
          'distance': Schema.num(
            description: 'Scroll distance in pixels (default 500)',
          ),
        },
      ),
      annotations: ToolAnnotations(destructiveHint: false, readOnlyHint: false),
    ),
    (request) async {
      final direction = request.arguments!['direction'] as String;
      final distance = (request.arguments?['distance'] as num?)?.toDouble();

      await actor.scroll(direction: direction, distance: distance ?? 500);

      return CallToolResult(
        content: [
          TextContent(
            text: jsonEncode({'status': 'scrolled', 'direction': direction}),
          ),
        ],
      );
    },
  );

  // type
  server.registerTool(
    Tool(
      name: 'type_text',
      description: 'Type text into an input field found by accessibility ID.',
      inputSchema: ObjectSchema(
        required: ['field', 'value'],
        properties: {
          'field': Schema.string(
            description: 'Accessibility ID of the input field',
          ),
          'value': Schema.string(description: 'Text to type'),
        },
      ),
      annotations: ToolAnnotations(destructiveHint: false, readOnlyHint: false),
    ),
    (request) async {
      final field = request.arguments!['field'] as String;
      final value = request.arguments!['value'] as String;

      await actor.type(field: field, value: value);

      return CallToolResult(
        content: [
          TextContent(text: jsonEncode({'status': 'typed', 'field': field})),
        ],
      );
    },
  );
}
