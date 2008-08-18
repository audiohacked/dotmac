/*  (c) Copyright 2006 Apple Computer, Inc. All rights reserved.  */
/* div display swapping */

var msg1 = "<div class='instrtextzone'><span class='body_emphasis'>" + WhyamItext1 + "</span><br><span class='body_text'>" + WhyamItext2 + "</span></div><a href='#' onclick='hideDisplay();' style='text-decoration: none;'><div class='buttonright_blue_lightgray'><div class='buttoncap_blue_lightgray'><div class='buttontext'>" + ButtonOK + "</div></div></div></a>";

var msg2 = "<div style='float: left; margin-top: 15px; margin-right: 10px;'><img border='0' width='32' height='32' src='/Comments.woa/Contents/WebServerResources/English.lproj/images/spinner.gif'></div><div style='display: table; height: 58px; _position: relative; overflow: hidden;'><div style='_position: absolute; _top: 50%;display: table-cell; vertical-align: middle;'><div class='instrtextzone' style='_position: relative; _top: -50%'><span class='big_emphasis'>" + Flickertext1 + "</span><br><span class='caption'>" + Flickertext2 + "</span></div></div></div>";

var msg4 = "<div style='float: left; margin-top: 5px; margin-right: 10px; margin-left: 10px;'><img border='0' width='32' height='32' src='/Comments.woa/Contents/WebServerResources/English.lproj/images/alert.gif'></div><div class='instrtextzone'><span class='body_emphasis'>" + error7 + "</span></div><a href='#' onclick='hideDisplay();' style='text-decoration: none;'><div class='buttonright_blue_lightgray'><div class='buttoncap_blue_lightgray'><div class='buttontext'>" + ButtonOK + "</div></div></div></a>";


function onPageLoad()
{
	   getCommentCookie();
	   initLightbox();
	   document.comment.commentMessage.focus();
}



function authenticate(scriptname) {
	if (bCatch) {
		try { 
			doAuthenticate(scriptname) 
		} catch (localException) {	
			alert("js:authenticate catched an exception: " + localException); 
		}
	} else {
		doAuthenticate(scriptname);
	}
}


function doAuthenticate(scriptname) {
    var commentMessage = document.getElementById("commentMessage");	
		commentMessage.value = cleanTags(commentMessage.value, 'b');
		commentMessage.value = cleanTags(commentMessage.value, 'i');
		commentMessage.value = cleanTags(commentMessage.value, 'u');

    // Checking client side errors
	if ( clientSideError() ) { return; }	

    var commentForm = document.forms['comment'];
    var authForm = document.forms['authform'];
		var captcha  = authForm["iv"].value;
		var theUrl = authForm["postURL"].value;
		var theScript = authForm[scriptname].value;
    var attDiv = document.getElementById("Attachment");
    if (attDiv != null) { var fup  = document.getElementById("fup"); }
		var username = authForm['username'].value;
		var userURL = authForm.userURL.value;
	
		// set cookie
		setCommentCookie(username, userURL);
		
		showDisplay(msg2, 'BoxMsg2');
		
		var connection = new DMHTTPConnection();
		var object = new Object;
		
		object['iv'] = captcha;
		object['postURL'] = theUrl;
		object['userURL'] = userURL;
		object[scriptname] = theScript;
		object['name'] = username;
	
		if(attDiv != null && fup && fup.value && attDiv.style.display != "none") {
			object['hasAttachment'] = "true";
		}
		
		connection.setRootObject(object);	
		connection.callMethod("xauthenticateUser", null, authenticateCallBackMethod, username);		
		return;
}


function authenticateCallBackMethod(status, xmlresponse,username) {
	if (bCatch) {
		try { 
			doAuthenticateCallBackMethod(status, xmlresponse, username) ;
		} catch (localException) {
			alert("js:authenticateCallBackMethod catched an exception: " + localException); 
		}
	} else {
			doAuthenticateCallBackMethod(status, xmlresponse, username) ;
	}
}



function doAuthenticateCallBackMethod(status, xmlresponse, username) {
	
	if(isValidResponse(xmlresponse)) {
		CommentFormCommit();
		return true;
	} else {
		var code = statusCodeForResponse(xmlresponse);
		// display error messages	
	    hideDisplay();
		if (code == 400) {
			showError("error2");
			return insertResponseWithIDMatchingCode(xmlresponse, "verificationImage", "verificationImage", 400);
		}
	    return false;
	}
}

function CommentFormCommit() {
	if (bCatch) {
		try { 
			doCommentFormCommit() 
		} catch (localException) {
			alert("js:verifyNicknameCallBackMethod catched an exception: " + localException);
		}
	} else {
		doCommentFormCommit() ;
	}
}

function doCommentFormCommit() {
	// check if the attachment field is present and if there is a value
		var theForm = document.forms['comment'];
		var attDiv = document.getElementById("Attachment");


		if(attDiv != null && theForm.fup && theForm.fup.value && attDiv.style.display != "none" && theForm.action.indexOf("?upload") < 0) {
				theForm.action += "?upload=Y";
		}
		theForm.submit();  

}


function showImageVerification() {
	var imageVerificationDiv = document.getElementById("imageVerification");
	if (imageVerificationDiv) { imageVerificationDiv.style.display = ""; }
}

function hideImageVerification() {
	var imageVerificationDiv = document.getElementById("imageVerification");
	if (imageVerificationDiv) { imageVerificationDiv.style.display = "none"; }
}

function promptImageVerification() {
	var imageVerificationDiv = document.getElementById("imageVerification");
	if (imageVerificationDiv && imageVerificationDiv.style.display == "none") {
		var verificationImageDiv = document.getElementById("verificationImage");
		imageVerificationDiv.style.display = "";
		if(verificationImageDiv && verificationImageDiv.innerHTML == ""){
			//alert("verificationImageDiv.innerHTML " + verificationImageDiv.innerHTML);
			refreshImageVerification();
		}
	} else {
		imageVerificationDiv.style.display = "";
	}
}

function refreshImageVerification() {
	var connection = new DMHTTPConnection();
	var object = new Object;
    var authForm = document.forms['authform'];
	var username = authForm["loginUsername"].value;
	var theUrl   = authForm["postURL"].value;
	object['postURL'] = theUrl;
	connection.setRootObject(object);	
	connection.callMethod("xpromptImageVerification", null, refreshImageVerificationCallBackMethod, username);
}

function refreshImageVerificationCallBackMethod(status, xmlresponse, username) {
	return insertResponseWithIDMatchingCode(xmlresponse, "verificationImage", "verificationImage", 0);
}

function hideCommentAsNotme() {
	var commentas2Div = document.getElementById("CommentAsInstr2");
	if (commentas2Div) { commentas2Div.style.display = "none"; }
	setCommentCookie("", "");
	getCommentCookie();
}

function showCommentAsNotme() {
	var commentas2Div = document.getElementById("CommentAsInstr2");
	if (commentas2Div) { commentas2Div.style.display = ""; }
}

function hideAttachmentUpload() {
	var linkDiv = document.getElementById("addAttachment");
	var attDiv = document.getElementById("Attachment");
    if (linkDiv) { linkDiv.style.display = ""; }
	if (attDiv) { attDiv.style.display = "none"; }
	document.attDeleteIcon.src='/Comments.woa/Contents/WebServerResources/English.lproj/images/delete.gif';
	// need to hide the captcha div here
	if(needsImageVerification != "true") 
	{
		hideImageVerification();
	}
}

function showAttachmentUpload() {
	var linkDiv = document.getElementById("addAttachment");
	var attDiv = document.getElementById("Attachment");
	if (linkDiv) { linkDiv.style.display = "none"; }
	if (attDiv) { attDiv.style.display = ""; }
	clearFileInput('fup','fup',21);
	
	// need to insert the captcha response data into the imageVerificationDIV
	// need to unhide the captcha div
	if(needsImageVerification != "true") 
	{
		promptImageVerification();
	}
}

function clearFileInput(name, id, size) {
	var oldFileInput = document.getElementById(id);
	var newFileInput = document.createElement("input");
	newFileInput.type="file";
	newFileInput.name=name;
	newFileInput.size=size;
	newFileInput.onkeypress = function() { return false; };
	oldFileInput.parentNode.replaceChild(newFileInput, oldFileInput);
	newFileInput.id = id;
}


function hideError(err) {
	var err2Div = document.getElementById("error2");
	var err3Div = document.getElementById("error3");
	var err17_1Div = document.getElementById("error17_1");
	var err17_2Div = document.getElementById("error17_2");
	var img1Div = document.getElementById("ImageVerinstr1");
	switch (err) {
	       case "error2" :
	            if (err2Div) { err2Div.style.display = "none"; }
	            if (img1Div) { img1Div.style.display = ""; }
	            break;
	       case "error3" :
	            if (err3Div) { err3Div.style.display = "none"; }
	            break;
	       case "error17_1" :
	            if (err17_1Div) { err17_1Div.style.display = "none"; }
	            break;
	       case "error17_2" :
	            if (err17_2Div) { err17_2Div.style.display = "none"; }
	            break;
	}
}

function showError(err) {
	var err2Div = document.getElementById("error2");
	var err3Div = document.getElementById("error3");
	var err17_1Div = document.getElementById("error17_1");
	var err17_2Div = document.getElementById("error17_2");
	var commentas2Div = document.getElementById("CommentAsInstr2");
	var img1Div = document.getElementById("ImageVerinstr1");
	var captcha  = document.getElementById("ivString");
	switch (err) {
	       case "error2" :
	            if (err2Div) { err2Div.style.display = ""; }
	            if (img1Div) { img1Div.style.display = "none"; }
	            if (captcha) { captcha.value = ""; }
	            break;
	       case "error3" :
	            if (err3Div) { err3Div.style.display = ""; }
	            break;
	       case "error17_1" :
	            if (err17_1Div) { err17_1Div.style.display = ""; }
	            if (commentas2Div) { commentas2Div.style.display = "none"; }
	            break;
	       case "error17_2" :
	            if (err17_2Div) { err17_2Div.style.display = ""; }
	            break;
	}
}

/* client side checking */
function clientSideError() {
    var hasError = false;    
    var username = document.getElementById("username").value;   
    var userURL = document.getElementById("userURL").value;
    var commentmessage = document.getElementById("commentMessage").value;
 	var nonspace=commentmessage.replace(/^\s+/g, '').replace(/\s+$/g, '');
    var attDiv = document.getElementById("Attachment");
    if (attDiv != null) { var fup  = document.getElementById("fup"); }
    var captcha  = document.getElementById("ivString").value;

	// checking <> " " in Comment as and URL
	if ( username.indexOf('<')>=0  && username.indexOf('>')>=0 ) {
	            showError("error17_1");
	            hasError = true;
	} else { hideError("error17_1"); }

	if ( userURL.length > 0 && !validUserURL(userURL)) {
	            showError("error17_2");
	            hasError = true;
	} else { hideError("error17_2"); }

    // checking non-space message length 	
	if(nonspace.length == 0 && (attDiv == null || (attDiv != null && (fup.value.length == 0 || attDiv.style.display == "none")))) {
		     showError("error3");
		     hasError = true;
	} else { hideError("error3"); }
	
	// verify that the captcha should be shown, if so then evaluate it
	if(captcha.length == 0) {
		     showError("error2");
		     hasError = true;
	} else { hideError("error2"); }

	// check attachment file type
	if(attDiv != null && fup && fup.value && attDiv.style.display != "none" && checkBundle(fup.value)) {
		     showDisplay(msg4, 'BoxMsg4');
		     hasError = true;
	}

	return hasError;
}

/* Email, url format validation */
function validUserURL(userurl) {

    var posAtSign = userurl.indexOf("@");
    var vLength = userurl.length;
    
    if ( userurl.indexOf('<')>=0 || userurl.indexOf('>')>=0 || userurl.indexOf(' ')>=0 || userurl.indexOf('"')>=0) {
        return false;
	} else if ( posAtSign >=0 ) {
	    // checking for format a@b.c
	    var posDot = (posAtSign + 2 < vLength) ? userurl.indexOf(".", posAtSign + 2) : -1;
		if (posDot < 0 || userurl.charAt(0) == '@' || userurl.charAt(posAtSign+1) == '.' || userurl.charAt(vLength-1) == '.') {
			return false;
		}
    } else {
	    // checking for format a.b
	    var posDot = userurl.indexOf(".");
		if (posDot < 0 || userurl.charAt(0) == '.' || userurl.charAt(vLength-1) == '.') {
			return false;
		}
    }
	return true;
}

/* Message Lightbox */
var objArray = new Array();

changeCSS = function(cssID){
	var objBoxMsg = document.getElementById('BoxMsg');
	objBoxMsg.setAttribute('id', cssID);
}

showErrorMsg = function(message){
	var objBoxMsg = document.getElementById('BoxMsg');
	objBoxMsg.innerHTML = message;	
}

showDisplay = function(msgString, cssID){
	this.showErrorMsg(msgString);
	this.changeCSS(cssID);
	for (var i=0;i<objArray.length;i++){		
		objArray[i].style.display = 'block';
	}
}

hideDisplay = function(){
	for (var i=0;i<objArray.length;i++){		
		objArray[i].style.display = 'none';
	}
	objArray[0].setAttribute('id', 'BoxMsg');
}

initLightbox = function(){
	if (!document.getElementsByTagName){ return; }
	var objBody = document.body;
	var objWrapper = document.getElementById("Wrapper");
		
	// create overlay div
	var objOverlay = document.createElement("div");
	objOverlay.setAttribute('id','overlay');
	objBody.insertBefore(objOverlay, objBody.firstChild);

	// create BoxMsg div
	var objBoxMsg = document.createElement("div");
	objBody.insertBefore(objBoxMsg, objWrapper);
	objBoxMsg.setAttribute('id','BoxMsg');
	objBoxMsg.style.display = 'none';	

	objArray[0] = objBoxMsg;
	objArray[1] = objOverlay;
}

/* disable return key */
function stopRKey(evt) {
	var evt  = (evt) ? evt : ((event) ? event : null);
	var node = (evt.target) ? evt.target : ((evt.srcElement) ? evt.srcElement : null);
	if ((evt.keyCode == 13) && (node.type=="text")) { return false; }
}

document.onkeypress = stopRKey;


/* check upload file extension */
function checkBundle (filename) {
    var localFilename = filename.indexOf('/')>=0 ? filename.split('/')[filename.split('/').length -1]:filename;
    localFilename = localFilename + '/';
    localFilename = localFilename.split(".");
    var extension = localFilename.length > 1 ? localFilename[localFilename.length - 1] : "";
	if (extension == 'key/'  ||  extension == 'pages/'  || extension == 'template/' ||extension == 'bundle/' || extension == '/backup' || extension == 'qdfm/' || extension == 'graffle/' || extension == 'oo3/' || extension == 'kth/' || extension == 'template/' || extension == 'app/' || extension == 'rtfd/' || extension == 'band/' || extension == 'wdgt/' || extension == 'FullBackup/' || extension == 'IncrementalBackup/' || extension == 'iMovieProject/' || extension == 'dvdproj/' || extension == 'xcodeproj/' || extension == 'xcode/' || extension == 'pkg/' || extension == 'plugin/' || extension == 'component/' || extension == 'vst/' || extension == 'wo/' || extension == 'eomodeld/' || extension == 'prefPane/' || extension == 'download/') {
		return true;
	}
	return false;
}

/* cookie manipulation*/
function setCommentCookie(name, url) {
	    setCookie("commentusername", name);
	    setCookie("commentUserURL", url);
}

function getCommentCookie() {
    var authForm = document.forms['authform'];
    var notmeMsg = document.getElementById('CommentAsInstr2');
    var commentusername = getCookie('commentusername');
    var notmeSpan = document.createElement('span');
    notmeSpan.className = "caption_dark";
    
	if (commentusername != null && commentusername != "") {
		 authForm["username"].value = commentusername; 
		 
		 // create 'not me' message and link
		 notmeSpan.appendChild(document.createTextNode(notme1));
		 var hideLink = document.createElement('a');
		 hideLink.href = '#';
		 hideLink.onclick = function() { hideCommentAsNotme(); return false; }
		 hideLink.appendChild(document.createTextNode(commentusername));
		 notmeSpan.appendChild(hideLink);
		 notmeSpan.appendChild(document.createTextNode(notme2));
		 
		 // append message to page
		 notmeMsg.innerHTML = "";
		 notmeMsg.appendChild(notmeSpan);		 
		 showCommentAsNotme();
	} else { authForm["username"].value = ""; }
	if (getCookie('commentUserURL') != null) {
	         authForm["userURL"].value = getCookie('commentUserURL');
	} else { authForm["userURL"].value = "";}
}

function setCookie(name, value) {
    var domain = "www.mac.com";
    var theDate = new Date();
    var oneDayLater = new Date( theDate.getTime() + 86400000 );
    if ( value != "") {
         document.cookie = name + "=" + escape(value) + ";domain=" + domain + ";path=/" + "; expires=" + oneDayLater.toGMTString();
    } else if ( value == "" && getCookie(name) != null ) {
         document.cookie = name + "=" + escape(getCookie(name)) + ";domain=" + domain + ";path=/" + "; expires=" + theDate.toGMTString();
    }
}

function getCookie(name)  {
    var cookies = document.cookie;
    var key = name + "=";
    var begin = cookies.indexOf("; " + key);
    if (begin == -1) {
        begin = cookies.indexOf(key);
        if (begin != 0) return null;
    } else {
       begin += 2;
    }
    var end = document.cookie.indexOf(";", begin);
    if (end == -1) {
        end = cookies.length;
    }
    return unescape(cookies.substring(begin + key.length, end));
}

function cleanTags(string, tag) {
	var openTag = new RegExp('<[\\s\\xA0]*' + tag + '[\\s\\xA0]*>','ig');
	var closeTag = new RegExp('</[\\s\\xA0]*' + tag + '[\\s\\xA0]*>','ig');
	var openTagSingle =  new RegExp('<[\\s\\xA0]*' + tag + '[\\s\\xA0]*>','i');
	var closeTagSingle =  new RegExp('</[\\s\\xA0]*' + tag + '[\\s\\xA0]*>','i');
	var remainder = string;
	
	// pair open tags with close tags
	while ((match = openTag.exec(string)) != null)  {		
		// if there's a close tag before the first open tag, remove it
		if (string.search(closeTag) <= match.index) {
			string = string.replace(closeTagSingle, '');
		}
		// mark the first open tag
		string = string.replace(openTagSingle, '[ccstart]');
		
		// mark the first close tag
		if (string.search(closeTag) >=0) {
			string = string.replace(closeTagSingle, '[ccend]');
		} else { //if there is no closing tag after this open tag, add an extra marker to the end
			string = string + '[ccend]';
		}
	}

	// if too many close tags after cleaning, remove the extras
	 if (string.search(closeTag) >=0) {
			string = string.replace(closeTag,'');
	 }
	 
	 // normalize case & replace placeholder tags
	 string = string.replace(/\[ccstart\]/ig, '<' + tag + '>');
	 string = string.replace(/\[ccend\]/ig, '</' + tag + '>');

	return string;
}

