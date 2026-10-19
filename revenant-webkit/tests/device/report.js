// Collects a page's verdicts and reports them in one request.
//
// The device cannot be asked for its DOM, so each page reports itself: the
// runner serves these pages from a plain HTTP server and reads the verdicts out
// of that server's own request log. One request per page rather than one per
// check, because a page that finishes while requests are still queued loses
// them - which is exactly what happened with one request per check.
(function () {
    var page = document.title || 'page';
    var verdicts = [];

    window.report = function (name, pass, detail) {
        verdicts.push((pass ? 'PASS' : 'FAIL') + '|' + name + '|' + String(detail === undefined ? '' : detail));
        // One request per page, at the end. Sending each verdict as it happens
        // was tried and is worse: this engine will not push a burst of image
        // requests out of a synchronous script, and most of them never left.
        // A page that can take the browser down therefore gets a page of its
        // own, so its silence costs only its own checks.
        var line = document.createElement('div');
        line.textContent = (pass ? 'PASS ' : 'FAIL ') + name + '  ' + (detail === undefined ? '' : detail);
        line.style.color = pass ? '#060' : '#a00';
        document.body.appendChild(line);
    };

    window.reportDone = function () {
        // final=1 is what the runner waits for: it means this page reached its
        // end rather than stopping somewhere in the middle.
        var url = '/verdicts?page=' + encodeURIComponent(page)
            + '&results=' + encodeURIComponent(verdicts.join('~~')) + '&final=1';
        new Image().src = url + '&t=' + Date.now();
    };
})();
