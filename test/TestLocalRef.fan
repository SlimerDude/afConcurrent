
@Js
internal class TestLocalRef : Test {
	
	Void testDocumentation() {
		man := T_Drink()
		man.beer.val = "Ale"
		
		kid := T_Drink()
		kid.beer.val = "Ginger Ale"
		
		verifyEq("Ale", man.beer.val)		   // --> Ale
		verifyEq("Ginger Ale", kid.beer.val)   // --> Ginger Ale
		
		verify(man.beer.qname.endsWith(".beer")) // --> 0001.beer
		verify(kid.beer.qname.endsWith(".beer")) // --> 0002.beer
	}
	
	Void testLazyInitFunc() {
		ref := LocalRef("init") |->Obj?| { 0 }
		verifyFalse(ref.isMapped)
		
		v := ref.val
		verify(ref.isMapped)
		
		ref.cleanUp
		verifyFalse(ref.isMapped)
	}

	// don't create a local ref when reading null! ('cos Synchronized does it a lot!)
	Void testLazyLazyInitFunc() {
		ref := LocalRef("lazy")
		verifyFalse(ref.isMapped)
		
		v := ref.val
		verifyFalse(ref.isMapped)
	}

	Void testNuffinSetByDefault() {
		ref := LocalRef("init", null)
		verifyFalse(ref.isMapped)

		ref.val = 0
		verify(ref.isMapped)

		ref.cleanUp
		verifyFalse(ref.isMapped)
	}
}

@Js
internal class T_Drink {
    LocalRef beer := LocalRef("beer")
}
