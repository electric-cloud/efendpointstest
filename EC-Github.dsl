

//	Create a dummy plugin to store the endpoint dsl
plugin "EC-Github", version: "1.0.0.0", {
	procedure "CreateConfiguration"
}

// Promote the dummy plugin
promotePlugin pluginName: "EC-Github-1.0.0.0"

// Add the sample webhook dsl
property "/plugins/EC-Github/project/ec_endpoints/webhook/dsl",
	value: '''\
		import groovy.json.*
		runProcedure procedureName: 'do nothing',
			projectName: 'Default',
				actualParameter: [
					payload: JsonOutput.toJson(args.payload),
					headers: JsonOutput.toJson(args.headers)
				]
	'''.stripIndent()

// Create the procedure to process the webhook
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
