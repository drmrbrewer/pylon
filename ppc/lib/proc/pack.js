ppc.process.handler.pack = function(x) {
    ppc.makeClass(this);
    this.inherit(ppc.ProjectBase);
    
    var s       = ppc.settings,
        input   = s.parseAttribute(x.getAttribute("input")),
        output  = s.parseAttribute(x.getAttribute("output")),
        combine = 'combine.xml';

    this.$loadPml = function(x) {
        ppc.console.info(x.parentNode.xml);
        ppc.console.info("Packing files...");
        var fs = o3.fs;

        var indexHtml = ppc.getXml(fs.get(input).data);

        combine = ppc.getXml('<j:application xmlns:j="http://www.javeline.com/2005/jml" />');

        var body      = indexHtml.selectSingleNode("body"),
            tempNodes = body.childNodes,
            i = tempNodes.length - 1;

        for (; i >= 0; i--) {
            if (tempNodes[i].tagName != 'loader')
                combine.insertBefore(tempNodes[i], combine.childNodes[0]);
        }

        var incl, fsNode, jml, pNode, nodes, j,
            path     = ppc.getDirname(input),
            includes = combine.selectNodes("//include");
        for (i = includes.length - 1; i >= 0; i--) {
            incl   = includes[i],
            fsNode = fs.get(path + incl.getAttribute('src'));

            if (!fsNode.exists)
                ppc.console.error("File not found: " + fs.path);
            
            jml   = ppc.getXml(fsNode.data),
            pNode = incl.parentNode,
            nodes = jml.childNodes;
            for (j = nodes.length - 1; j >= 0; j--)
                pNode.insertBefore(nodes[j], incl);
            pNode.removeChild(incl);
        }

        var skin,
            skins = combine.selectNodes("//skin[@src]");
        for (i = skins.length - 1; i >= 0; i--) {
            skin   = skins[i],
            fsNode = fs.get(path + skin.getAttribute('src'));

            if (!fsNode.exists)
                ppc.console.error("File not found: " + fs.path);

            jml   = ppc.getXml(fsNode.data),
            nodes = jml.childNodes;
            ppc.xmldb.integrate(skin, jml, {
                copyAttributes : true
            });
        }

        var scripts = combine.selectNodes("//script[@src]");
        for (var i = scripts.length - 1; i >= 0; i--) {
            var script = scripts[i];
            var fsNode = fs.get(path + script.getAttribute('src'));

            if (!fsNode.exists)
                ppc.console.error("File not found: " + fs.path);

            var code   = fsNode.data.replace(/\r/g, "");
            script.removeAttribute("src"); //createCDATASection
            script.appendChild(script.ownerDocument.createTextNode(code));
        }

        //createElementNS("j:include", "http://www.javeline.com/2005/jml");
        var jmlIncl = body.appendChild(body.ownerDocument.createElement("j:include"));
        jmlIncl.setAttribute("src", "combined.xml");

        var file = cwd.get("projects/" + s.parseAttribute(ppc.getXmlValue(x, "//defines/@defaults")));

        if (!file.exists) {
            ppc.console.error("File not found " + file.path);
            throw new Error();
        }

        var xml = ppc.getXml(file.data),
            n   = xml.selectNodes("//define");

        var defNode, node, name, l,
            defines = x.selectSingleNode("//defines");
        for (i = 0, l = n.length; i < l; i++) {
            node = n[i];
            name = node.getAttribute("name");
            if (combine.selectSingleNode('//' + node.getAttribute("match").replace(/j\:/g,"").split("|").join("|//"))
              && !defines.selectSingleNode("define[@name='" + name + "']")
              && node.getAttribute("match") != "") {
                //createElementNS("define", "http://www.javeline.com/2008/Processor")
                defNode = defines.appendChild(defines.ownerDocument.createElement("p:define"));
                defNode.setAttribute("value", "1");
                defNode.setAttribute("name", name);
                defines.appendChild(defNode);
            }
        }

        var z, ppcEl = [];
        nodes = combine.selectNodes("//node()");
        for (i = 0; i < nodes[i]; i++) {
            node = nodes[i];
            if (node.tagName == "skin")
                return;
            
            ppcEl[node.tagName] = true;
            if (z == node.getAttribute("skin"))
                ppcEl[z] = true;
        }

        nodes = combine.selectNodes('//skin/node()[local-name()]');
        for (i = nodes.length - 1; i >= 0 ; i--) {
            if (!ppcEl[nodes[i].getAttribute("name")])
                nodes[i].parentNode.removeChild(nodes[i]);
        }

        ppc.console.info("Writing index.html to " + output);
        fs.get(output + "/index.html").data  = indexHtml.xml;
        ppc.console.info("Writing combine.xml to " + output);
        fs.get(output + "/combine.xml").data = combine.xml;
    };
};
