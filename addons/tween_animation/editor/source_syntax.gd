@tool
extends RefCounted
## A non-executing source index. Offsets always refer to the original text.
## Unsupported control flow remains visible to the semantic analyzer as uncertain.

static func mask(source: String) -> String:
	var result := ""
	var index := 0
	while index < source.length():
		var character := source[index]
		if character == "#" or source.substr(index, 2) == "//":
			while index < source.length() and source[index] != "\n":
				result += " "
				index += 1
		elif source.substr(index, 2) == "/*":
			result += "  "
			index += 2
			while index < source.length() and source.substr(index, 2) != "*/":
				result += "\n" if source[index] == "\n" else " "
				index += 1
			if index < source.length():
				result += "  "
				index += 2
		elif character in ["\"", "'"]:
			var quote := character.repeat(3) if source.substr(index, 3) == character.repeat(3) else character
			var verbatim := index > 0 and source[index - 1] == "@" and quote.length() == 1
			result += " ".repeat(quote.length())
			index += quote.length()
			while index < source.length():
				if verbatim and source.substr(index, 2) == quote.repeat(2):
					result += "  "
					index += 2
				elif source.substr(index, quote.length()) == quote:
					result += " ".repeat(quote.length())
					index += quote.length()
					break
				elif source[index] == "\\" and not verbatim and index + 1 < source.length():
					result += " " + ("\n" if source[index + 1] == "\n" else " ")
					index += 2
				else:
					result += "\n" if source[index] == "\n" else " "
					index += 1
		else:
			result += character
			index += 1
	return result


static func matching(masked: String, start: int) -> int:
	var opening := masked[start]
	var closing: String = {"(": ")", "[": "]", "{": "}"}.get(opening, "")
	var depth := 0
	for index in range(start, masked.length()):
		if masked[index] == opening:
			depth += 1
		elif masked[index] == closing:
			depth -= 1
			if depth == 0:
				return index
	return -1


static func line_at(source: String, offset: int) -> int:
	return source.left(offset).count("\n") + 1


static func arguments(source: String, masked: String, start: int, end: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var depth := 0
	var part := start
	for index in range(start, end + 1):
		var character := masked[index] if index < end else ","
		if character in ["(", "[", "{"]:
			depth += 1
		elif character in [")", "]", "}"]:
			depth -= 1
		elif character == "," and depth == 0:
			var left := part
			var right := index
			while left < right and source[left] in [" ", "\t", "\r", "\n"]:
				left += 1
			while right > left and source[right - 1] in [" ", "\t", "\r", "\n"]:
				right -= 1
			if right > left:
				result.append({"start": left, "end": right, "text": source.substr(left, right - left)})
			part = index + 1
	return result


static func methods(source: String, language: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var masked := mask(source)
	var regex := RegEx.new()
	regex.compile("(?m)^[ \\t]*(?:static[ \\t]+)?func[ \\t]+([A-Za-z_]\\w*)[ \\t]*\\(" if language == "gd" else "(?m)^[ \\t]*(?:(?:public|private|protected|internal|static|async|override|virtual|sealed|partial|new)[ \\t]+)*(?:[A-Za-z_][\\w.<>?,\\[\\]]*)[ \\t]+([A-Za-z_]\\w*)[ \\t]*\\(")
	for found in regex.search_all(masked):
		var name := found.get_string(1)
		if name in ["if", "for", "while", "switch", "return", "catch"]:
			continue
		var opening := masked.find("(", found.get_start(1) + name.length())
		var closing := matching(masked, opening)
		if closing < 0:
			continue
		var head := found.get_start()
		var line_start := source.rfind("\n", found.get_start(1)) + 1
		var indent := source.substr(line_start, found.get_start(1) - line_start)
		indent = indent.left(indent.length() - indent.lstrip(" \t").length())
		var body := closing + 1
		var end := source.length()
		if language == "gd":
			body = masked.find(":", closing)
			if body < 0:
				continue
			body += 1
			var cursor := masked.find("\n", body)
			if cursor < 0:
				cursor = source.length()
			while cursor < source.length():
				var next := masked.find("\n", cursor + 1)
				if next < 0:
					next = source.length()
				var line := masked.substr(cursor + 1, next - cursor - 1)
				var whitespace := line.length() - line.lstrip(" \t").length()
				if not line.strip_edges().is_empty() and whitespace <= indent.length():
					end = cursor + 1
					break
				cursor = next
		else:
			while body < masked.length() and masked[body] in [" ", "\t", "\r", "\n"]:
				body += 1
			if body >= masked.length() or masked[body] != "{":
				continue
			end = matching(masked, body)
			body += 1
			if end < 0:
				continue
		var parameters: Array[Dictionary] = []
		for argument in arguments(source, masked, opening + 1, closing):
			var declaration: String = str(argument.text).get_slice("=", 0).strip_edges()
			var pieces := declaration.split(":") if language == "gd" else declaration.split(" ", false)
			parameters.append({"name": pieces[0].strip_edges() if language == "gd" else pieces[-1], "type": pieces[1].strip_edges() if language == "gd" and pieces.size() > 1 else (pieces[-2] if language == "cs" and pieces.size() > 1 else "Variant")})
		result.append({"id": str(head), "name": name, "start": head, "body": body, "end": end, "line": line_at(source, found.get_start(1)), "indent": indent, "parameters": parameters, "static": "static " in source.substr(head, opening - head), "language": language})
	return result


static func statements(source: String, method: Dictionary) -> Array[Dictionary]:
	var masked := mask(source)
	var result: Array[Dictionary] = []
	var depth := 0
	var scope := 0
	var start := int(method.body)
	for index in range(start, int(method.end)):
		var character := masked[index]
		if character in ["(", "["] or (character == "{" and method.language == "gd"):
			depth += 1
		elif character in [")", "]"] or (character == "}" and method.language == "gd"):
			depth -= 1
		var boundary: bool = depth == 0 and ((method.language == "gd" and character in ["\n", ";"]) or (method.language == "cs" and character in [";", "{", "}"]))
		if boundary:
			var left := start
			while left < index and masked[left] in [" ", "\t", "\r", "\n"]:
				left += 1
			if left < index:
				var line_start := source.rfind("\n", left) + 1
				var prefix := source.substr(line_start, left - line_start)
				var indent := prefix if prefix.strip_edges().is_empty() else str(method.indent) + ("\t" if method.language == "gd" else "    ")
				result.append({"start": left, "end": index + (1 if character == ";" else 0), "line": line_at(source, left), "indent": indent, "text": source.substr(left, index - left + (1 if character == ";" else 0)), "scope": scope, "conditional": scope > 0 or (method.language == "gd" and indent.length() > str(method.indent).length() + (1 if indent.begins_with("\t") else 4)), "block": character in ["{", "}"]})
			if method.language == "cs":
				scope += 1 if character == "{" else (-1 if character == "}" else 0)
			start = index + 1
	if start < int(method.end) and not masked.substr(start, int(method.end) - start).strip_edges().is_empty():
		result.append({"start": start, "end": int(method.end), "line": line_at(source, start), "indent": str(method.indent) + "\t", "text": source.substr(start, int(method.end) - start), "scope": scope, "conditional": scope > 0, "block": false})
	if method.language == "gd" and not result.is_empty():
		var baseline := 100000
		for statement in result:
			baseline = mini(baseline, str(statement.indent).length())
		for statement in result:
			statement.conditional = str(statement.indent).length() > baseline
	return result


static func calls(source: String, statement: Dictionary) -> Array[Dictionary]:
	var masked := mask(source)
	var regex := RegEx.new()
	regex.compile("\\b([A-Za-z_]\\w*)[ \\t\\r\\n]*\\(")
	var result: Array[Dictionary] = []
	for found in regex.search_all(masked.substr(statement.start, statement.end - statement.start)):
		var start: int = statement.start + found.get_start(1)
		var opening := masked.find("(", start + found.get_string(1).length())
		var closing := matching(masked, opening)
		if closing < 0 or closing > int(statement.end):
			continue
		var receiver := ""
		var cursor := start - 1
		while cursor >= int(statement.start) and masked[cursor] in [" ", "\t"]:
			cursor -= 1
		if cursor >= int(statement.start) and masked[cursor] == ".":
			var right := cursor
			cursor -= 1
			var brackets := 0
			while cursor >= int(statement.start):
				var character := masked[cursor]
				if character in [")", "]"]:
					brackets += 1
				elif character in ["(", "["]:
					brackets -= 1
				if brackets == 0 and (character in [" ", "\t", "\n", "=", ";", "+", "-"]):
					break
				cursor -= 1
			receiver = source.substr(cursor + 1, right - cursor - 1)
		result.append({"name": found.get_string(1), "api": found.get_string(1).to_snake_case(), "start": start, "end": closing + 1, "opening": opening, "args": arguments(source, masked, opening + 1, closing), "receiver": receiver, "deferred": "func(" in masked.substr(statement.start, start - statement.start).replace(" ", "") or "=>" in masked.substr(statement.start, start - statement.start), "line": line_at(source, start)})
	return result
