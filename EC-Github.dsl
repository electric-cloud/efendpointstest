

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

		return [contentType: 'text/plain', body: 'success answer from EF']
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

		step "Show Repository", shell: "ec-groovy", command: '''\
			import groovy.json.*
			import com.electriccloud.client.groovy.ElectricFlow
			ElectricFlow ef = new ElectricFlow()
			def result = ef.getProperty(propertyName: "payload")

			def jsonSlurper = new JsonSlurper()
			def payload = jsonSlurper.parseText(result.property.value)

			println payload.repository.full_name
		'''.stripIndent()
	}
}
