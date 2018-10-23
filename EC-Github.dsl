plugin "EC-Github", version: "1.0.0.0", {
	procedure "CreateConfiguration"
}

promotePlugin pluginName: "EC-Github-1.0.0.0"

property("/plugins/EC-Github/project/ec_endpoints/webhook/dsl", value:"runProcedure(procedureName: 'do nothing', projectName: 'Default', actualParameter: [payload: (String) args.payload, headers: (String) args.headers])")

// TODO: payload and headers JSON is incorrect, {testfield=abc}

project "Default", {
	procedure "do nothing",{
		formalParameter "payload"
		formalParameter "headers"
		step "echo payload and headers", command: '''\
			echo payload: $[payload]
			echo headers: $[headers]
		'''.stripIndent()
	}
}
