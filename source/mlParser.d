module com.cterm2.mlParser;

public import com.cterm2.mlDocumentTree;
import std.range, std.variant, std.algorithm, std.stdio, std.utf, std.uni;
import std.typecons;

struct ParsedData(T)
{
	static if(!is(T == void)) T value;
	string rest;
}
alias Empty = int;
alias ParseResult(T) = Algebraic!(ParsedData!T, Empty);
auto Succeeded(V)(V value, string r)
{
	return ParseResult!V(ParsedData!V(value, r));
}
auto Succeeded(string r)
{
	return ParseResult!void(ParsedData!void(r));
}
auto Failed(V)()
{
	return ParseResult!V(Empty());
}

unittest
{
	assert("<!DOCTYPE html>"._DefinitionHeader.peek!(ParsedData!DefinitionHeader) !is null);
	assert("<!DOCTYPE html PUBLIC \"TestID\" \"htps://test.org/\">"._DefinitionHeader.peek!(ParsedData!DefinitionHeader) !is null);
	assert("<!DOCTYPE html PUBLIC \"TestID\">"._DefinitionHeader.peek!(ParsedData!DefinitionHeader) is null);
	assert("\"test\""._StringLiteral.peek!(ParsedData!string).rest.empty);
	assert("<p>test</p>"._Tag.peek!(ParsedData!Tag) !is null);
	assert("<p>test<b>bold</b>text and <s>deleted</s></p>"._Tag.peek!(ParsedData!Tag) !is null);
	auto parsedStructure = "<!DOCTYPE html>
<html>
	<head><title>Sample HTML</title></head>
	<body>
		<p>Paragraph 1</p>
		<h1>Header #1<small>-Subtitle-</small></h1>
		<p>Paragraph 2<br /><b>bold test</b></p>
	</body>
</html>".mlParseString.peek!(ParsedData!Document);
	assert(parsedStructure !is null);
	assert(parsedStructure.value.isStrictForm == true);
	assert(parsedStructure.value.firstTag.name == parsedStructure.value.header.firstTagName);
}

auto mlParseString(string input)
{
	auto r = input._Document;
	auto rd = r.peek!(ParsedData!Document);
	if(rd is null) return Failed!Document;
	if(!rd.rest.empty) return Failed!Document;
	return r;
}

auto _Document(string input)
{
	// Document: DefinitionHeader Tag / Tag
	auto alt2()
	{
		auto firstTag = input.ignoreSpaces._Tag.peek!(ParsedData!Tag);
		if(firstTag is null) return Failed!Document;
		return Succeeded(Document.NonStrictForm(firstTag.value), firstTag.rest);
	}
	auto alt1()
	{
		auto defHeader = input.ignoreSpaces._DefinitionHeader.peek!(ParsedData!DefinitionHeader);
		if(defHeader is null) return alt2();
		auto firstTag = defHeader.rest.ignoreSpaces._Tag.peek!(ParsedData!Tag);
		if(firstTag is null) return alt2();
		return Succeeded(Document.StrictForm(defHeader.value, firstTag.value), firstTag.rest);
	}

	return alt1();
}
auto _DefinitionHeader(string input)
{
	// DefinitionHeader: "<!DOCTYPE" Identifier "PUBLIC" StringLiteral StringLiteral">" / "<!DOCTYPE" Identifier">"
	auto alt2()
	{
		auto defHeaderStr = input._String("<!DOCTYPE").peek!(ParsedData!void);
		if(defHeaderStr is null) return Failed!DefinitionHeader;
		auto firstTagName = defHeaderStr.rest.ignoreSpaces._Identifier.peek!(ParsedData!string);
		if(firstTagName is null) return Failed!DefinitionHeader;
		auto tagTerm = firstTagName.rest._String(">").peek!(ParsedData!void);
		if(tagTerm is null) return Failed!DefinitionHeader;
		return Succeeded(DefinitionHeader.ShortForm(firstTagName.value), tagTerm.rest);
	}
	auto alt1()
	{
		auto defHeaderStr = input._String("<!DOCTYPE").peek!(ParsedData!void);
		if(defHeaderStr is null) return alt2();
		auto firstTagName = defHeaderStr.rest.ignoreSpaces._Identifier.peek!(ParsedData!string);
		if(firstTagName is null) return alt2();
		auto sanityPublic = firstTagName.rest.ignoreSpaces._String("PUBLIC").peek!(ParsedData!void);
		if(sanityPublic is null) return alt2();
		auto defid = sanityPublic.rest.ignoreSpaces._StringLiteral.peek!(ParsedData!string);
		if(defid is null) return alt2();
		auto defurl = defid.rest.ignoreSpaces._StringLiteral.peek!(ParsedData!string);
		if(defurl is null) return alt2();
		auto tagTerm = defurl.rest._String(">").peek!(ParsedData!void);
		if(tagTerm is null) return alt2();
		return Succeeded(DefinitionHeader.LongForm(firstTagName.value, defid.value, defurl.value), tagTerm.rest);
	}

	return alt1();
}
ParseResult!Tag _Tag(string input)
{
	/+
	Tag: "<"Identifier AttributeList"/>"
		/ "<script" AttributeList">" Text "</script>"
		/ <"Identifier AttributeList">" ContentList "</"Identifier">"
		/ "<"Identifier AttributeList">"
	+/
	auto alt4()
	{
		auto tagFirst = input._String("<").peek!(ParsedData!void);
		if(tagFirst is null) return Failed!Tag;
		auto tagName = tagFirst.rest._Identifier.peek!(ParsedData!string);
		if(tagName is null) return Failed!Tag;
		auto attributeList = tagName.rest.ignoreSpaces._AttributeList.peek!(ParsedData!(string[string]));
		if(attributeList is null) return Failed!Tag;
		auto tagTerm = attributeList.rest._String(">").peek!(ParsedData!void);
		if(tagTerm is null) return Failed!Tag;
		return Succeeded(new Tag(tagName.value, attributeList.value, null), tagTerm.rest);
	}
	auto alt3()
	{
		auto tagFirst = input._String("<").peek!(ParsedData!void);
		if(tagFirst is null) return alt4();
		auto tagName = tagFirst.rest._Identifier.peek!(ParsedData!string);
		if(tagName is null) return alt4();
		auto attributeList = tagName.rest.ignoreSpaces._AttributeList.peek!(ParsedData!(string[string]));
		if(attributeList is null) return alt4();
		auto tagTerm = attributeList.rest._String(">").peek!(ParsedData!void);
		if(tagTerm is null) return alt4();
		auto contents = tagTerm.rest._ContentList.peek!(ParsedData!(Content[]));
		if(contents is null) return alt4();
		auto termTagFirst = contents.rest._String("</").peek!(ParsedData!void);
		if(termTagFirst is null) return alt4();
		auto termTagName = termTagFirst.rest._Identifier.peek!(ParsedData!string);
		if(termTagName is null) return alt4();
		if(!termTagName.value.asLowerCase.equal(tagName.value.asLowerCase)) return alt4();
		auto termTagClosure = termTagName.rest._String(">").peek!(ParsedData!void);
		if(termTagClosure is null) return alt4();
		return Succeeded(new Tag(tagName.value, attributeList.value, contents.value), termTagClosure.rest);
	}
	auto alt2()
	{
		auto tagFirst = input._String("<script").peek!(ParsedData!void);
		if(tagFirst is null) return alt3();
		auto attributeList = tagFirst.rest.ignoreSpaces._AttributeList.peek!(ParsedData!(string[string]));
		if(attributeList is null) return alt3();
		auto tagTerm = attributeList.rest._String(">").peek!(ParsedData!void);
		if(tagTerm is null) return alt3();
		auto scriptData = tagTerm.rest._ScriptBlock.peek!(ParsedData!string);
		if(scriptData is null) return alt3();
		auto tagTermSet = input._String("</script>").peek!(ParsedData!void);
		if(tagTermSet is null) return alt3();
		return Succeeded(new Tag("script", attributeList.value, [TextContent(scriptData.value)]), tagTermSet.rest);
	}
	auto alt1()
	{
		auto tagFirst = input._String("<").peek!(ParsedData!void);
		if(tagFirst is null) return alt2();
		auto tagName = tagFirst.rest._Identifier.peek!(ParsedData!string);
		if(tagName is null) return alt2();
		auto attributeList = tagName.rest.ignoreSpaces._AttributeList.peek!(ParsedData!(string[string]));
		if(attributeList is null) return alt2();
		auto tagTerm = attributeList.rest._String("/>").peek!(ParsedData!void);
		if(tagTerm is null) return alt2();
		return Succeeded(new Tag(tagName.value, attributeList.value, null), tagTerm.rest);
	}

	return alt1();
}
auto _AttributeList(string input)
{
	// AttributeList: Attribute*
	// Attribute: Identifier "=" StringLiteral / Identifier "=" Identifier
	alias AttributeSet = Tuple!(string, string);
	static auto _Attribute(string input)
	{
		auto alt2()
		{
			auto key = input._Identifier.peek!(ParsedData!string);
			if(key is null) return Failed!AttributeSet;
			auto con = key.rest.ignoreSpaces._String("=").peek!(ParsedData!void);
			if(con is null) return Failed!AttributeSet;
			auto val = con.rest.ignoreSpaces._Identifier.peek!(ParsedData!string);
			if(val is null) return Failed!AttributeSet;
			return Succeeded(AttributeSet(key.value, val.value), val.rest);
		}
		auto alt1()
		{
			auto key = input._Identifier.peek!(ParsedData!string);
			if(key is null) return alt2();
			auto con = key.rest.ignoreSpaces._String("=").peek!(ParsedData!void);
			if(con is null) return alt2();
			auto val = con.rest.ignoreSpaces._StringLiteral.peek!(ParsedData!string);
			if(val is null) return alt2();
			return Succeeded(AttributeSet(key.value, val.value), val.rest);
		}

		return alt1();
	}

	auto processRange = input;
	string[string] attributes;
	while(true)
	{
		auto set = _Attribute(processRange).peek!(ParsedData!AttributeSet);
		if(set is null) break;
		attributes[set.value[0]] = set.value[1];
		processRange = set.rest.ignoreSpaces;
	}
	return Succeeded(attributes, processRange);
}
auto _ContentList(string input)
{
	// ContentList: Content*
	// Content: Text / Tag
	static auto _Content(string input)
	{
		if(input.startsWith("</"))
		{
			return Failed!Content;
		}
		auto t = input._Text.peek!(ParsedData!string);
		if(t !is null) return Succeeded(TextContent(t.value), t.rest);
		auto t2 = input._Tag.peek!(ParsedData!Tag);
		if(t2 is null) return Failed!Content;
		return Succeeded(TagContent(t2.value), t2.rest);
	}

	auto processRange = input;
	Content[] clist;
	while(true)
	{
		auto c = _Content(processRange).peek!(ParsedData!Content);
		if(c is null) break;
		clist ~= c.value;
		processRange = c.rest;
	}
	return Succeeded(clist, processRange);
}
auto _Text(string input)
{
	// *Get characters while isContentTrap returns false*
	auto processRange = input;
	dchar[] fetchedRange = null;
	while(!processRange.empty && !processRange.front.isContentTrap)
	{
		fetchedRange ~= processRange.front;
		processRange = processRange.drop(1);
	}
	if(fetchedRange.empty) return Failed!string;
	return Succeeded(fetchedRange.toUTF8, processRange);
}
auto _ScriptBlock(string input)
{
	// *Get characters while processRange doesn't start with "</script>"*
	auto processRange = input;
	dchar[] fetchedRange = null;
	while(!processRange.empty && !processRange.asLowerCase.startsWith("</script>"))
	{
		fetchedRange ~= processRange.front;
		processRange = processRange.drop(1);
	}
	return Succeeded(fetchedRange.toUTF8, processRange);
}
auto _Identifier(string input)
{
	auto processRange = input;
	dchar[] fetchedRange = null;

	while(!processRange.empty && !processRange.front.isStreamTrap)
	{
		fetchedRange ~= processRange.front;
		processRange = processRange.drop(1);
	}
	return fetchedRange.empty ? Failed!string : Succeeded(fetchedRange.toUTF8, processRange);
}
auto _StringLiteral(string input)
{
	auto processRange = input;
	dchar[] fetchedRange = null;

	if(processRange.front != '"') return Failed!string;
	fetchedRange ~= processRange.front;
	processRange = processRange.drop(1);
	bool isEscaping = false;
	while(!processRange.empty && (isEscaping || processRange.front != '"'))
	{
		if(isEscaping) isEscaping = false;
		else if(processRange.front == '\\') isEscaping = true;
		fetchedRange ~= processRange.front;
		processRange = processRange.drop(1);
	}
	if(isEscaping && processRange.empty) return Failed!string;
	if(processRange.empty || processRange.front != '"') return Failed!string;
	fetchedRange ~= processRange.front;
	processRange = processRange.drop(1);
	return Succeeded(fetchedRange.toUTF8, processRange);
}
auto _String(string input, string target)
{
	return input.asLowerCase.startsWith(target.asLowerCase) ? Succeeded(input.drop(target.length)) : Failed!void;
}

// Parser Support Utils
pure:
auto isSpaces(dchar c) { return [' ', '\n', '\r', '\t'].any!(a => c == a); }
auto isStreamTrap(dchar c) { return c.isSpaces || ['<', '>', '!', '?', '/'].any!(a => c == a); }
auto isContentTrap(dchar c) { return c == '<'; }

auto ignoreSpaces(string input)
{
	auto processRange = input;

	while(!processRange.empty && processRange.front.isSpaces) processRange = processRange.drop(1);
	return processRange;
}
