function handler(event) {
    var request = event.request;
    var uri = request.uri || "/";
    var accept = "";
    
    // Get Accept header if it exists
    if (request.headers.accept && request.headers.accept.value) {
        accept = request.headers.accept.value;
    }
    
    // Only rewrite if:
    // 1. URI doesn't contain a dot (no file extension)
    // 2. Accept header includes text/html (browser request)
    if (uri.indexOf('.') === -1 && accept.indexOf('text/html') !== -1) {
        request.uri = '/index.html';
    }
    
    return request;
}
