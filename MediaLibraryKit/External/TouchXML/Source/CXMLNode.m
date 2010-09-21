//
//  CXMLNode.m
//  TouchCode
//
//  Created by Jonathan Wight on 03/07/08.
//  Copyright 2008 toxicsoftware.com. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//

#import "CXMLNode.h"

#import "CXMLNode_PrivateExtensions.h"
#import "CXMLDocument.h"
#import "CXMLElement.h"

#include <libxml/xpath.h>
#include <libxml/xpathInternals.h>
#include <libxml/xmlIO.h>

static int MyXmlOutputWriteCallback(void * context, const char * buffer, int len);
static int MyXmlOutputCloseCallback(void * context);


@implementation CXMLNode

- (void)dealloc
{
if (_node)
	{
	if (_node->_private == self)
		_node->_private = NULL;

	if (_freeNodeOnRelease)
		{
		xmlFreeNode(_node);
		}

	_node = NULL;
	}
//
[super dealloc];
}

- (id)copyWithZone:(NSZone *)zone;
{
xmlNodePtr theNewNode = xmlCopyNode(_node, 1);
CXMLNode *theNode = [[[self class] alloc] initWithLibXMLNode:theNewNode freeOnDealloc:YES];
theNewNode->_private = theNode;
return(theNode);
}

#pragma mark -

- (CXMLNodeKind)kind
{
NSAssert(_node != NULL, @"CXMLNode does not have attached libxml2 _node.");
return(_node->type); // TODO this isn't 100% accurate!
}

- (NSString *)name
{
NSAssert(_node != NULL, @"CXMLNode does not have attached libxml2 _node.");
// TODO use xmlCheckUTF8 to check name
if (_node->name == NULL)
	return(NULL);
else
	return([NSString stringWithUTF8String:(const char *)_node->name]);
}

- (NSString *)stringValue
{
NSAssert(_node != NULL, @"CXMLNode does not have attached libxml2 _node.");
xmlChar *theXMLString;
BOOL theFreeReminderFlag = NO;
if (_node->type == XML_TEXT_NODE || _node->type == XML_CDATA_SECTION_NODE)
	theXMLString = _node->content;
else
	{
	theXMLString = xmlNodeListGetString(_node->doc, _node->children, YES);
	theFreeReminderFlag = YES;
	}

NSString *theStringValue = NULL;
if (theXMLString != NULL)
	{
	theStringValue = [NSString stringWithUTF8String:(const char *)theXMLString];
	if (theFreeReminderFlag == YES)
		{
		xmlFree(theXMLString);
		}
	}

return(theStringValue);
}

- (NSUInteger)index
{
NSAssert(_node != NULL, @"CXMLNode does not have attached libxml2 _node.");

xmlNodePtr theCurrentNode = _node->prev;
NSUInteger N;
for (N = 0; theCurrentNode != NULL; ++N, theCurrentNode = theCurrentNode->prev)
	;
return(N);
}

- (NSUInteger)level
{
NSAssert(_node != NULL, @"CXMLNode does not have attached libxml2 _node.");

xmlNodePtr theCurrentNode = _node->parent;
NSUInteger N;
for (N = 0; theCurrentNode != NULL; ++N, theCurrentNode = theCurrentNode->parent)
	;
return(N);
}

- (CXMLDocument *)rootDocument
{
NSAssert(_node != NULL, @"CXMLNode does not have attached libxml2 _node.");

return(_node->doc->_private);
}

- (CXMLNode *)parent
{
NSAssert(_node != NULL, @"CXMLNode does not have attached libxml2 _node.");

if (_node->parent == NULL)
	return(NULL);
else
	return (_node->parent->_private);
}

- (NSUInteger)childCount
{
NSAssert(_node != NULL, @"CXMLNode does not have attached libxml2 _node.");

xmlNodePtr theCurrentNode = _node->children;
NSUInteger N;
for (N = 0; theCurrentNode != NULL; ++N, theCurrentNode = theCurrentNode->next)
	;
return(N);
}

- (NSArray *)children
{
NSAssert(_node != NULL, @"CXMLNode does not have attached libxml2 _node.");

NSMutableArray *theChildren = [NSMutableArray array];
xmlNodePtr theCurrentNode = _node->children;
while (theCurrentNode != NULL)
	{
	CXMLNode *theNode = [CXMLNode nodeWithLibXMLNode:theCurrentNode freeOnDealloc:NO];
	[theChildren addObject:theNode];
	theCurrentNode = theCurrentNode->next;
	}
return(theChildren);
}

- (CXMLNode *)childAtIndex:(NSUInteger)index
{
NSAssert(_node != NULL, @"CXMLNode does not have attached libxml2 _node.");

xmlNodePtr theCurrentNode = _node->children;
NSUInteger N;
for (N = 0; theCurrentNode != NULL && N != index; ++N, theCurrentNode = theCurrentNode->next)
	;
if (theCurrentNode)
	return([CXMLNode nodeWithLibXMLNode:theCurrentNode freeOnDealloc:NO]);
return(NULL);
}

- (CXMLNode *)previousSibling
{
NSAssert(_node != NULL, @"CXMLNode does not have attached libxml2 _node.");

if (_node->prev == NULL)
	return(NULL);
else
	return([CXMLNode nodeWithLibXMLNode:_node->prev freeOnDealloc:NO]);
}

- (CXMLNode *)nextSibling
{
NSAssert(_node != NULL, @"CXMLNode does not have attached libxml2 _node.");

if (_node->next == NULL)
	return(NULL);
else
	return([CXMLNode nodeWithLibXMLNode:_node->next freeOnDealloc:NO]);
}

//- (CXMLNode *)previousNode;
//- (CXMLNode *)nextNode;
//- (NSString *)XPath;

- (NSString *)localName
{
NSAssert(_node != NULL, @"CXMLNode does not have attached libxml2 _node.");
// TODO use xmlCheckUTF8 to check name
if (_node->name == NULL)
	return(NULL);
else
	return([NSString stringWithUTF8String:(const char *)_node->name]); // TODO this is the same as name. What's up with thaat?
}

- (NSString *)prefix
{
if (_node->ns)
	return([NSString stringWithUTF8String:(const char *)_node->ns->prefix]);
else
	return(NULL);
}

- (NSString *)URI
{
if (_node->ns)
	return([NSString stringWithUTF8String:(const char *)_node->ns->href]);
else
	return(NULL);
}

//+ (NSString *)localNameForName:(NSString *)name;
//+ (NSString *)prefixForName:(NSString *)name;
//+ (CXMLNode *)predefinedNamespaceForPrefix:(NSString *)name;

- (NSString *)description
{
NSAssert(_node != NULL, @"CXMLNode does not have attached libxml2 _node.");

return([NSString stringWithFormat:@"<%@ %p [%p] %@ %@>", NSStringFromClass([self class]), self, self->_node, [self name], [self XMLStringWithOptions:0]]);
}

- (NSString *)XMLString
{
return([self XMLStringWithOptions:0]);
}

- (NSString *)XMLStringWithOptions:(NSUInteger)options
{
NSMutableData *theData = [[NSMutableData alloc] init];

xmlOutputBufferPtr theOutputBuffer = xmlOutputBufferCreateIO(MyXmlOutputWriteCallback, MyXmlOutputCloseCallback, theData, NULL);

xmlNodeDumpOutput(theOutputBuffer, _node->doc, _node, 0, 0, "utf-8");

xmlOutputBufferFlush(theOutputBuffer);

NSString *theString = [[[NSString alloc] initWithData:theData encoding:NSUTF8StringEncoding] autorelease];

xmlOutputBufferClose(theOutputBuffer);

return(theString);
}
//- (NSString *)canonicalXMLStringPreservingComments:(BOOL)comments;

- (NSArray *)nodesForXPath:(NSString *)xpath error:(NSError **)error
{
#pragma unused (error)

NSAssert(_node != NULL, @"CXMLNode does not have attached libxml2 _node.");

NSArray *theResult = NULL;

xmlXPathContextPtr theXPathContext = xmlXPathNewContext(_node->doc);
theXPathContext->node = _node;

// TODO considering putting xmlChar <-> UTF8 into a NSString category
xmlXPathObjectPtr theXPathObject = xmlXPathEvalExpression((const xmlChar *)[xpath UTF8String], theXPathContext);
if (theXPathObject == NULL)
	{
	if (error)
		*error = [NSError errorWithDomain:@"TODO_DOMAIN" code:-1 userInfo:NULL];
	return(NULL);
	}
if (xmlXPathNodeSetIsEmpty(theXPathObject->nodesetval))
	theResult = [NSArray array]; // TODO better to return NULL?
else
	{
	NSMutableArray *theArray = [NSMutableArray array];
	int N;
	for (N = 0; N < theXPathObject->nodesetval->nodeNr; N++)
		{
		xmlNodePtr theNode = theXPathObject->nodesetval->nodeTab[N];
		[theArray addObject:[CXMLNode nodeWithLibXMLNode:theNode freeOnDealloc:NO]];
		}

	theResult = theArray;
	}

xmlXPathFreeObject(theXPathObject);
xmlXPathFreeContext(theXPathContext);
return(theResult);
}

//- (NSArray *)objectsForXQuery:(NSString *)xquery constants:(NSDictionary *)constants error:(NSError **)error;
//- (NSArray *)objectsForXQuery:(NSString *)xquery error:(NSError **)error;


@dynamic node;



- (id)initWithLibXMLNode:(xmlNodePtr)inLibXMLNode freeOnDealloc:(BOOL)infreeOnDealloc
{
    if ((self = [super init]) != NULL)
	{
        _node = inLibXMLNode;
        _freeNodeOnRelease = infreeOnDealloc;
	}
    return(self);
}

+ (id)nodeWithLibXMLNode:(xmlNodePtr)inLibXMLNode freeOnDealloc:(BOOL)infreeOnDealloc
{
    // TODO more checking.
    if (inLibXMLNode->_private)
        return(inLibXMLNode->_private);

    Class theClass = [CXMLNode class];
    switch (inLibXMLNode->type)
	{
        case XML_ELEMENT_NODE:
            theClass = [CXMLElement class];
            break;
        case XML_DOCUMENT_NODE:
            theClass = [CXMLDocument class];
            break;
        case XML_ATTRIBUTE_NODE:
        case XML_TEXT_NODE:
        case XML_CDATA_SECTION_NODE:
        case XML_COMMENT_NODE:
            break;
        default:
            NSAssert1(NO, @"TODO Unhandled type (%d).", inLibXMLNode->type);
            return(NULL);
	}

    CXMLNode *theNode = [[[theClass alloc] initWithLibXMLNode:inLibXMLNode freeOnDealloc:infreeOnDealloc] autorelease];


    if (inLibXMLNode->doc != NULL)
	{
        CXMLDocument *theXMLDocument = inLibXMLNode->doc->_private;
        if (theXMLDocument != NULL)
		{
            NSAssert([theXMLDocument isKindOfClass:[CXMLDocument class]] == YES, @"TODO");

            [[theXMLDocument nodePool] addObject:theNode];

            theNode->_node->_private = theNode;
		}
	}
    return(theNode);
}


- (NSString *)stringValueForXPath:(NSString *)string
{
    NSArray *nodes = [self nodesForXPath:string error:nil];
    if ([nodes count] == 0)
        return nil;
    return [[nodes objectAtIndex:0] stringValue];
}

- (NSNumber *)numberValueForXPath:(NSString *)string
{
    NSArray *nodes = [self nodesForXPath:string error:nil];
    if ([nodes count] == 0)
        return nil;
    NSScanner *scanner = [NSScanner scannerWithString:[[nodes objectAtIndex:0] stringValue]];
    NSInteger i;
    if ([scanner scanInteger:&i])
        return [NSNumber numberWithInteger:i];
    return nil;
}

- (xmlNodePtr)node
{
    return(_node);
}

@end

static int MyXmlOutputWriteCallback(void * context, const char * buffer, int len)
{
NSMutableData *theData = context;
[theData appendBytes:buffer length:len];
return(len);
}

static int MyXmlOutputCloseCallback(void * context)
{
NSMutableData *theData = context;
[theData release];
return(0);
}
