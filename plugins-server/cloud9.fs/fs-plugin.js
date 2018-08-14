var assert = require("assert");
var path = require("path");
var error = require("http-error");

var jsDAV = require("cozy-jsdav-fork");
var jsDAV_Tree_Filesystem = require("./fs/tree");
var BrowserPlugin = require("cozy-jsdav-fork/lib/DAV/plugins/browser");
var DavFilewatch = require("./dav/filewatch");
var DavPermission = require("./dav/permission");

module.exports = function setup(options, imports, register) {

    assert(options.urlPrefix);

    var permissions = imports["workspace-permissions"];

    imports.sandbox.getProjectDir(function(err, projectDir) {
        if (err) return register(err);

        imports.sandbox.getWorkspaceId(function(err, workspaceId) {
            if (err) return register(err);

            init(projectDir, workspaceId);
        });
    });

    function init(projectDir, workspaceId) {
        var mountDir = path.normalize(projectDir);

        var davOptions = {
            path: mountDir,
            mount: options.urlPrefix,
            plugins: options.davPlugins,
            server: {},
            standalone: false
        };

        davOptions.tree = jsDAV_Tree_Filesystem.new(imports.vfs, mountDir);

        var filewatch = new DavFilewatch();

        var davServer = jsDAV.mount(davOptions);
        davServer.plugins["filewatch"] = filewatch.getPlugin();
        davServer.plugins["browser"] = BrowserPlugin;
        davServer.plugins["permission"] = DavPermission;

        imports.connect.useAuth(function(req, res, next) {
            if (req.url.indexOf(options.urlPrefix) !== 0)
                return next();

            if (!req.session || !(req.session.uid || req.session.anonid))
                return next(new error.Unauthorized());

            permissions.getPermissions(req.session.uid, workspaceId, "cloud9.fs.fs-plugin", function(err, permissions) {
                if (err) {
                    next(err);
                    return;
                }

                davServer.permissions = permissions.fs;
                davServer.exec(req, res);
            });
        });

        register(null, {
            "onDestroy": function() {
                davServer.unmount();
            },
            "dav": {
                getServer: function() {
                    return davServer;
                }
            },
            "fs": {
                on: filewatch.on.bind(filewatch),
                addListener: filewatch.on.bind(filewatch),
                removeListener: filewatch.removeListener.bind(filewatch)
            },
            "codesearch": {},
            "filesearch": {}
        });
    }
};
