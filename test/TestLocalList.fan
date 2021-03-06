
//@Js
internal class TestLocalList : ConcurrentTest {

	Void testLazyCreation() {
		list := LocalList("list")
		
		verifyFalse(list.localRef.isMapped)
		list.add(3)
		verify(list.localRef.isMapped)

		// Not convinced I should remove empty Lists it from Actor.locals?
		// It seems a bit underhand and unexpected - and to what performance gain?
		// And should I also do the same for Atomic and Sync lists?
//		list.clear
//		verifyFalse(list.localRef.isMapped)
	}
	
	// because local lists and maps tend to be numerous (one per thread!), 
	// try not to create loads of empty ones for useless methods
	Void testLazyLazyCreation() {
		echo("1")
		list := LocalList("list")
		echo("1.4")
		verifyFalse(list.localRef.isMapped)
		echo("2")
		
		list.clear
		verifyFalse(list.localRef.isMapped)
		echo("3")

		verifyFalse(list.contains(6))
		verifyFalse(list.localRef.isMapped)

		list.each { it.toStr }
		verifyFalse(list.localRef.isMapped)
		
		verifyErrMsg(IndexErr#, "0") {
			a := list[0]
		}
		verifyFalse(list.localRef.isMapped)
		
		verify(list.isEmpty)
		verifyFalse(list.localRef.isMapped)

		verifyEq(list.size, 0)
		verifyFalse(list.localRef.isMapped)
	}
	
	Void testListType() {
		verifyEq(LocalList("list") { valType = Obj?# }.val.typeof,	Obj?[]#)			
		verifyEq(LocalList("list") { valType = Obj?# }.val.of, 		Obj?#)

		verifyEq(LocalList("list") { valType = Str?# }.val.typeof,	Str?[]#)			
		verifyEq(LocalList("list") { valType = Str?# }.val.of,		Str?#)

		verifyEq(LocalList("list") { valType = Int# }.val.typeof,	Int[]#)			
		verifyEq(LocalList("list") { valType = Int# }.val.of, 		Int#)
	}
	
	Void testListTypeChecks() {
		list := LocalList("list") { valType = Str# }
		
		verifyErrMsg(ArgErr#, ConcurrentUtils.wrongType(Int#, Str#, "List value")) {
			list.add(39)
		}
		
		verifyErrMsg(ArgErr#, ConcurrentUtils.wrongType(Int[]#, Str[]#, "List")) {
			list.val = Int[,]
		}

		verifyErrMsg(ArgErr#, ConcurrentUtils.wrongType(null, Str#, "List value")) {
			list.add(null)
		}
	}
}
