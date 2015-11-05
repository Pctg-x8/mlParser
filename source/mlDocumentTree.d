module com.cterm2.mlDocumentTree;

import std.variant;

class Document
{
	public const DefinitionHeader header;
	public const Tag firstTag;

	private this(const DefinitionHeader header, const Tag firstTag)
	{
		this.header = header;
		this.firstTag = firstTag;
	}
	public static auto NonStrictForm(const Tag ft)
	{
		return new Document(null, ft);
	}
	public static auto StrictForm(const DefinitionHeader hdr, const Tag ft)
	{
		return new Document(hdr, ft);
	}
	public @property isStrictForm() const { return this.header !is null; }
}
class DefinitionHeader
{
	public const string firstTagName, defId, defUrl;

	private this(const string ftn, const string di, const string du)
	{
		this.firstTagName = ftn;
		this.defId = di;
		this.defUrl = du;
	}
	public static auto LongForm(const string ftn, const string di, const string du)
	{
		return new DefinitionHeader(ftn, di, du);
	}
	public static auto ShortForm(const string ftn)
	{
		return new DefinitionHeader(ftn, null, null);
	}
	public @property isLongForm() const { return this.defId !is null && this.defUrl !is null; }
}
class Tag
{
	public const string name;
	public const string[string] attributes;
	public const Content[] innerContents;

	public this(const string n, const string[string] at, const Content[] ic)
	{
		this.name = n;
		this.attributes = at;
		this.innerContents = ic;
	}
}
alias Content = Algebraic!(Tag, string);		/+ Tag or Text +/
auto TextContent(const string t) { return Content(t); }
auto TagContent(const string n, const string[string] at, const Content[] ic) { return Content(new Tag(n, at, ic)); }
auto TagContent(const Tag t) { return Content(t); }
