/* Copyright (c) 2005 by Apple Computer, Inc.  All Rights Reserved. */

var kXMLStartDocument = '<?xml version="1.0"?>';
var kDMVersion = 'DMHTTPConnection/0.1';
var kDMHeaderVersion = 'x-dmhttpversion';
var kDMTimeStampParameter = 'ts';
var kDMXMLPropertyList = '<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0">\n';
var kDMXMLClosingPropertyList = '\n</plist>';
var kDMPropertyListArray = 'array';
var kDMPropertyListDictionary = 'dict';
var kDMPropertyListString = 'string';
var kDMResponseTag = 'response'; // response will be <response status='value'>...</response>
var kDMResponseContentTag = 'content';
var kDMAttributeStatus = 'status';
var kDMAttributeID = 'id';
var kDMResponseOK = 1;

var kDMMethodPOST = 'POST';
var kDMMethodGET = 'GET';
var kDMHeaderContentType = 'Content-Type';
var kDMXMLMimeType = 'text/xml';

// HTTP Status
var kHTTP_OK = 200;
var kHTTP_FOUND = 302;
var kHTTP_NOT_MODIFIED = 304;
var kHTTP_ERROR = 400;
var kHTTP_NOT_UNAUTHORIZED = 401;
var kHTTP_NOT_FORBIDDEN = 403;
var kHTTP_NOT_FOUND = 404;

var _woRootURL; // something like /WebObjects/App.woa

if (!String.prototype.toDocumentFragment) {
	String.prototype.toDocumentFragment = function toDocumentFragment(context) {
		var aRange=document.createRange();
		context= context || document.getElementsByTagName("body")[0];
		aRange.selectNodeContents(context);
		return aRange.createContextualFragment(this);
	}
}

function DMCurrentWOAppURL() {
	var string = document.URL; 
	if (string.substring(0,4) == "http") {
		var components = string.split("/");
		if (components.length > 4) {
			var baseURL = "/" + components[3] + "/" + components[4] + "/";
			return baseURL;
		}
	}
	return null;
}

function DMConnectionRegisterWebObjectsURL(rootURL) {
	_woRootURL = rootURL;
	if (_woRootURL) {
		var position = _woRootURL.length - 1;
		if (position > 0) {
			if (_woRootURL.lastIndexOf("/", position) != position) {
				_woRootURL += "/"; // append the last /
			}
		}
	}
}

var _requestMapping = new Object;

function DMConnectionRegisterRequestMapping(requestName, woDirectActionName) {
	_requestMapping[requestName] = woDirectActionName;
}

function _mappingURLFor(requestName) {
	if (!_woRootURL) {
		_woRootURL = DMCurrentWOAppURL();
	}
	var string = _woRootURL + "wa/";
	var daName = _requestMapping[requestName];
	if (daName != undefined) {
		string += daName;
	} else {
		string += requestName;
	}
	return string;
}

function xmlNodeValue(xmlTree, xmlNodeName) {
	var node = xmlTree.getElementsByTagName(xmlNodeName)[0];
	if (!node) { return ""; }
	if (node.childNodes.length > 1) {
	   node = node.childNodes[1];
	}
	return node.firstChild.nodeValue;
}

function DMGetTransport() {
	if (window.XMLHttpRequest) {
		return new XMLHttpRequest();
	} else if (window.ActiveXObject && navigator.userAgent.indexOf("Mac") < 0) {
		// Handle I.E PC
		return new ActiveXObject("Microsoft.XMLHTTP");
	}
	return null;
}

function _impl_handlestatechange(request, callbackFunction, connection, callbackContext) {
	if (request.readyState == 4) {
		if (request.status >= kHTTP_ERROR) {
			if (connection) { connection.onResponseError("Status returned: " + request.status); }
			return;
		}
		// Valid status... Let's see the content
		try {
			callbackFunction(request.status, request.responseXML, callbackContext, request);
		} catch (e2) {
			if (connection) { connection.onError("Callback function error:" + e2); }
		}
	}
}

function DMHTTPConnection() {
	// Private API for handling the state change	
    this.onError = function(errorMessage) { alert("onError: " + errorMessage); };
    this.onResponseError = function(errorMessage) { alert("onResponseError: " + errorMessage); };
    this.nodes = new Array();
    this.rootNode = null;
    this.namespace = null;
    this.headers = null;
    this.rootObject = null;
	
    this.setRootNamespace = function(rootXmlStr, namespaceStr) {
        this.rootNode = rootXmlNodeStr;
        this.namespace = namespaceStr;
    }
    this.callMethod = function(requestName, parameter, cbFunction, cbContext) {
		var xmlRequest = DMGetTransport();
		if (xmlRequest == null) {
			this.onError("Unable to get a transport object (XMLHttpRequest)");
			return;
		}
		try {
			// handle Safari, FireFox and others
			var xmlContent;
			var defeatCacheString = kDMTimeStampParameter + "=" + new Date().getTime();
			var url;
			if (requestName.charAt(0) == '/') {
				url = requestName; 
			} else {
				url = _mappingURLFor(requestName);
			}
			if (parameter) { url += "?" + parameter + "&"; } 
			else { url += "?"; }
			url += defeatCacheString;
			var contentData = null;
			var shouldSetXMLContentType = false;
			var method;
			if (this.rootObject) { // Encode this root object
				method = kDMMethodPOST;
				shouldSetXMLContentType = true;
				var serializer = new DMXMLSerializer();
				try {
					contentData = serializer.serialize(this.rootObject);
				} catch (ex) {
					this.onError('Serialization of rootObject ' + rootObject + ' failed. Exception: ' + ex);
				}
			} else if (this.nodes.length > 0) {
				// Build the content 
				method = kDMMethodPOST;
				// Build the content to post
				contentData = kXMLStartDocument;
				if (this.rootNode) {
					contentData += "<" + this.rootNode;
					if (this.namespace) {
						contentData += " xmlns=" + this.namespace;
					}
					contentData += ">";
				}
				// Append all the elements
				contentData += this.nodes.join("");
				// Close as needed
				if (this.rootNode) {
					contentData += "</" + this.rootNode + ">";
				}
				shouldSetXMLContentType = true;
			} else {
				method = kDMMethodGET;
			}
			xmlRequest.open(method, url, true);
			// check if we have nodes
			if (shouldSetXMLContentType) {
				xmlRequest.setRequestHeader(kDMHeaderContentType, kDMXMLMimeType);        
			}
			// Install custom handler for Request
			var connection = this;
			xmlRequest.onreadystatechange = function() { _impl_handlestatechange(xmlRequest, cbFunction, connection, cbContext); }
			// Push other headers
			if (this.headers && this.headers.length > 0) {
				var components, max = this.headers.length;
				for(i=0;i<max;i++) {
					components = this.headers[i].split(":");
					xmlRequest.setRequestHeader(components[0], components[1]);
				}
			}
			// Push the DM version
			xmlRequest.setRequestHeader(kDMHeaderVersion, kDMVersion);
			// Ready to call
			xmlRequest.send(contentData);
		} catch (gexception) {
			this.onError("Global Exception while preparing to send data:" + gexception);
		}
    }
    
    this.addNode = function(key, value) {
        node = "<" + key + ">" + value + "</" + key +">";
        this.nodes.push(node);
    }
    
    this.addHeader = function(key, value) {
        if (this.headers == null) { this.headers = new Array(); }
        this.headers.push(key + ":" + value);
    }    
	
	this.setRootObject = function(theRoot) {
		this.rootObject = theRoot;
	}
}

// ====================
// Convenient API to manage XMLHttpRequest response
function httpStatusCodeForResponse(xmlResponse) {
	return xmlResponse.status;
}

function statusCodeForResponse(xmlResponse) {
	var status = 0;
	try {
		status = parseInt(xmlResponse.getElementsByTagName(kDMResponseTag)[0].getAttribute(kDMAttributeStatus));
	} catch (ex) {
		status = -1;
	}
	return status;
}

function responseCodeMatch(xmlResponse, code) {
    return statusCodeForResponse(xmlResponse) == code;
}

function isValidResponse(xmlResponse) {
    return responseCodeMatch(xmlResponse, kDMResponseOK);
}

function htmlStringForResponse(xmlResponse) {
	var string = '';
	try {
		var nodeResponse = xmlResponse.getElementsByTagName(kDMResponseContentTag)[0];
		string = nodeResponse.firstChild.nodeValue;
	} catch (ex) {
	}
	return string;
}

function insertResponseString(xmlResponse, divName) {
	var result = false;
	if (xmlResponse && isValidResponse(xmlResponse)) {
		var divToProcess = document.getElementById(divName);
		if (divToProcess) {
			divToProcess.innerHTML = htmlStringForResponse(xmlResponse);
			result = true;
		}
	}
	return result;
}

function htmlStringForNode(node) {
	var string = '';
	try {
	   var childNodes = node.childNodes;
	   var i, max = childNodes ? childNodes.length : 0;
	   for(i=0;i<max;i++) {
	       string += childNodes[i].nodeValue;
	   }
	} catch (ex) {
	}
	return string;
}

function contentNodeWithID(xmlResponse, responseID) {
	var allContents = xmlResponse.getElementsByTagName(kDMResponseContentTag);
    var i, max = allContents.length;
    var contentNode;
    for(i=0;i<max;i++) {
        contentNode = allContents[i];
        if (contentNode.getAttribute(kDMAttributeID) == responseID) {
            return contentNode;
        }
    }
    return null;
}

function insertResponseWithIDMatchingCode(xmlResponse, responseID, divName, code) {
	var result = false;
	if (xmlResponse && responseCodeMatch(xmlResponse, code)) {
		if (!divName) {
			divName = responseID;
		}
		var divToProcess = document.getElementById(divName);
		if (divToProcess) {
		    var contentNode = contentNodeWithID(xmlResponse, responseID);
		    if (contentNode) {
                divToProcess.innerHTML = htmlStringForNode(contentNode);
                result = true;
		    }
		}
	}
	return result;
}

function insertResponseWithID(xmlResponse, responseID, divName) {
    if (!divName) {
        divName = responseID;
    }
    return insertResponseWithIDMatchingCode(xmlResponse, responseID, divName, kDMResponseOK);
}

function evalResponseString(xmlResponse, responseID) {
	if (xmlResponse && isValidResponse(xmlResponse)) {
        var contentNode = contentNodeWithID(xmlResponse, responseID);
        if (contentNode) {
            var str = htmlStringForNode(contentNode);
            try {
                eval(str);
            } catch (ex) {
                alert("Exception while executing evalResponseString: " + ex);
            }
        }
	}
}

// ============================================================
function DMXMLSerializer() {
	this.serialize = function(rootObject) {
		var string = kDMXMLPropertyList;
		string += this.serializeObject(rootObject, '');
		string += kDMXMLClosingPropertyList;
		return string;
	}
	
	this.serializeObject = function(oneObject,spacer) {
		var spaceFormatter = spacer != null ? spacer : '';
		var spaceNextFormatter = spacer + "    ";
		// check object type
		var stringSerialized = spaceFormatter;
		if ((oneObject.charAt && oneObject.substring) || isNaN(oneObject) == false) {
			stringSerialized += "<" + kDMPropertyListString + ">" + this.escape(""+oneObject) + "</" + kDMPropertyListString+ ">";
		} else if (oneObject instanceof Boolean) {
			stringSerialized += oneObject ? "<true/>" : "<false/>";
		} else if (oneObject instanceof Date) {
			stringSerialized += "<" + kDMPropertyListString + ">" + oneObject.getTime() + "</" + kDMPropertyListString + ">";
		} else if (oneObject instanceof Array) {
			var value, i, max;
			stringSerialized += '<' + kDMPropertyListArray + '>\n';
			max = oneObject.length;
			for(i=0;i<max;i++) {
				value = oneObject[i];
				try {
					stringSerialized += spaceFormatter + this.serializeObject(value, spaceNextFormatter) + "\n";
				} catch (exception) {
				}
			}
			stringSerialized += spaceFormatter + "</" + kDMPropertyListArray + ">";
		} else { // dictionary
			var name, key, value;
			stringSerialized += "<" + kDMPropertyListDictionary + ">\n";
			for (name in oneObject) {
				try { key = this.escape(""+name); } catch (ex) { key = null; }
				try { value = this.serializeObject(oneObject[name], spaceNextFormatter); } catch (ex2) { value = null; }
				if (key != null && value != null) {
					stringSerialized += spaceFormatter + "<key>" + key + "</key>\n" + spaceFormatter + value + "\n";
				}
			}
			stringSerialized += spaceFormatter + "</" + kDMPropertyListDictionary + ">";
		}
		return stringSerialized;
	}
	
	this.escape = function(aString) {
		// Replace all the well known entities
		var result = aString.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&apos;");
return result;
	}

	this.unescape = function(aString) {
		// Replace all the well known entities
		var result = aString.replace(/&apos;/g,'\'').replace(/&quot;/g,"\"").replace(/&gt;/g,">").replace(/&lt;/g,"<").replace(/&amp;/g,"&");
		return result;
	}


}
