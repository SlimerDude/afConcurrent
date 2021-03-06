
@NoDoc	// advanced use only
const class ConcurrentModule {
	
	Str:Obj nonInvasiveIocModule() {
		[
			"services"	: [
				[
					"id"	: ActorPools#.qname,
					"type"	: ActorPools#,
					"scopes": ["root"]
				],
				[
					"id"	: LocalRefManager#.qname,
					"type"	: LocalRefManager#,
					"scopes": ["root"]
				]
			],

			"contributions" : [
				[
					"serviceId"	: "afIoc::DependencyProviders",
					"key"		: "afConcurrent.localRefProvider",
					"build"		: LocalRefProvider#
				],
				[
					"serviceId"	: "afIoc::DependencyProviders",
					"key"		: "afConcurrent.synchronizedProvider",
					"build"		: SynchronizedProvider#
				]
			]
		]
	}
	
}
