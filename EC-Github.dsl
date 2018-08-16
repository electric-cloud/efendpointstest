plugin "EC-Github", {
    version = "1.0.0.0"
    property("/plugins/EC-Github/project/ec_endpoints/webhook/dsl", value:"runProcedure(procedureName: 'do nothing', projectName: 'Default')")
}

project "Default", {
    procedure "do nothing"
}
