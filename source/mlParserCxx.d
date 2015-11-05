import com.cterm2.mlParser;
import std.string, std.stdio, std.conv;

// mlParser Interfacing to C++

// Create objective classes and impl receptor producing methods.
// const(char)* must be copied
extern(C++)
{
	interface IDocumentReceptor
	{
		IDefinitionHeaderReceptor requestDefinitionHeaderReceptor();
		ITagReceptor requestFirstTagReceptor();
	}
	interface IDefinitionHeaderReceptor
	{
		void setFirstTagName(const(char)* pFirstTagName);
		void setDefinitionId(const(char)* pDefinitionId);
		void setDefinitionUrl(const(char)* pDefinitionUrl);
	}
	interface ITagReceptor
	{
		void setName(const(char)* pName);
		void setAttribute(const(char)* pKey, const(char)* pVal);
		IContentReceptor requestNewContentReceptor();
	}
	interface IContentReceptor
	{
		ITagReceptor requestTagReceptor();
		void setText(const(char)* pText);
	}
}

import core.runtime;
import core.stdc.stdio;

shared static this()
{
	//Runtime.initialize();
	printf("StartDLL\n");
	writeln("StartDLL");
}
shared static ~this()
{
	writeln("EndDLL");
	printf("EndDLL\n");
	//Runtime.terminate();
}

extern(C)
{
	// Return value means same as main()
	int parseString(const(char)* pInput, IDocumentReceptor receptor)
	{
		auto cop = pInput.fromStringz.idup;
		auto r = mlParseString(cop);
		auto rd = r.peek!(ParsedData!Document);
		if(rd is null) return 1;					// Error

		// Copying Datas to Receptor(Expected implemented in C++)
		if(rd.value.isStrictForm) receptor.requestDefinitionHeaderReceptor().copy(rd.value.header);
		receptor.requestFirstTagReceptor().copy(rd.value.firstTag);
		return 0;									// Succeeded
	}
}

void copy(IDefinitionHeaderReceptor receptor, const DefinitionHeader origin)
{
	receptor.setFirstTagName(origin.firstTagName.toStringz);
	receptor.setDefinitionId(origin.defId.toStringz);
	receptor.setDefinitionUrl(origin.defUrl.toStringz);
}
void copy(ITagReceptor receptor, const Tag origin)
{
	receptor.setName(origin.name.toStringz);
	foreach(k, v; origin.attributes)
	{
		receptor.setAttribute(k.toStringz, v.toStringz);
	}
	foreach(c; origin.innerContents)
	{
		receptor.requestNewContentReceptor().copy(c);
	}
}
void copy(IContentReceptor receptor, const Content origin)
{
	if(origin.type() == typeid(Tag))
	{
		receptor.requestTagReceptor().copy(origin.get!Tag);
	}
	else
	{
		receptor.setText(origin.get!string.toStringz);
	}
}
