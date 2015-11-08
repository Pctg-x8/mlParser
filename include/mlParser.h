#pragma once

// MLParser Importing Header

class IDefinitionHeaderReceptor;
class ITagReceptor;
class IDocumentReceptor
{
public:
	virtual IDefinitionHeaderReceptor* requestDefinitionHeaderReceptor() = 0;
	virtual ITagReceptor* requestFirstTagReceptor() = 0;
};
class IDefinitionHeaderReceptor
{
public:
	virtual void setFirstTagName(const char* pFirstTagName) = 0;
	virtual void setDefinitionId(const char* pDefinitionId) = 0;
	virtual void setDefinitionUrl(const char* pDefinitionUrl) = 0;
};
class IContentReceptor;
class ITagReceptor
{
public:
	virtual void setName(const char* pName) = 0;
	virtual void setAttribute(const char* pKey, const char* pVal) = 0;
	virtual IContentReceptor* requestNewContentReceptor() = 0;
};
class IContentReceptor
{
public:
	virtual ITagReceptor* requestTagReceptor() = 0;
	virtual void setText(const char* pText) = 0;
};

typedef int(*mlParseString)(const char* pInput, IDocumentReceptor* pReceptor);
