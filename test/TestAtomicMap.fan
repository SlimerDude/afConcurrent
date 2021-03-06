
@Js
internal class TestAtomicMap : ConcurrentTest {

	Void testDef() {
		val := AtomicMap() { it.def = 69 }.get("wotever")
		verifyEq(val, 69)
	}

	Void testOrdered() {
		map := AtomicMap() { it.ordered = true }
		map[3] = 3
		map[1] = 1
		map[2] = 2
		verifyEq(map.keys, Obj[3, 1, 2])
	}

	Void testCaseInsensitive() {
		map := AtomicMap() { it.caseInsensitive = true }
		map["wot"] = "ever"
		verifyEq(map["WOT"], "ever")
	}

	Void testMutableMap() {
		verifyErr(NotImmutableErr#) {
			AtomicMap().val = [0:NotImmutable()]			
		}
	}

	Void testMutableSet() {
		verifyErr(NotImmutableErr#) {
			AtomicMap()[0] = NotImmutable()			
		}
	}

	Void testMutableGetOrAdd() {
		verifyErr(NotImmutableErr#) {
			AtomicMap().getOrAdd(0) { NotImmutable() }			
		}

		// allowed 'cos the func need not be mutable
		AtomicMap().getOrAdd(0) { datum }
		
		// allow nulls to be added - surprisingly, 'null.toImmutable' doesn't throw an Err!
		AtomicMap().getOrAdd(69) { null }		
	}
	private Obj datum() { 69 }
	
	Void testMapType() {
		verifyEq(AtomicMap() { keyType = Obj#; valType = Obj?# }.val.typeof,	[Obj:Obj?]#)			
		verifyEq(AtomicMap() { keyType = Int#; valType = Str?# }.val.typeof,	[Int:Str?]#)			
		verifyEq(AtomicMap() { keyType = Int#; valType = Str#  }.val.typeof,	[Int:Str]#)
	}
	
	Void testMapTypeChecks() {
		map := AtomicMap() { keyType = Int#; valType = Str# }
		
		verifyErrMsg(ArgErr#, ConcurrentUtils.wrongType(Str#, Int#, "Map key")) {
			map["str"] = "str"
		}

		verifyErrMsg(ArgErr#, ConcurrentUtils.wrongType(Str#, Int#, "Map key")) {
			map.getOrAdd("str") { "str" }
		}
		
		verifyErrMsg(ArgErr#, ConcurrentUtils.wrongType(Int#, Str#, "Map value")) {
			map[13] = 13
		}

		verifyErrMsg(ArgErr#, ConcurrentUtils.wrongType(Int#, Str#, "Map value")) {
			map.getOrAdd(13) { 13 }
		}
		
		verifyErrMsg(ArgErr#, ConcurrentUtils.wrongType(Int:Obj#, Int:Str#, "Map")) {
			map.val = Int:Obj[:]
		}
		
		verifyErrMsg(ArgErr#, ConcurrentUtils.wrongType(null, Str#, "Map value")) {
			map[13] = null
		}
	}
}

@Js
class NotImmutable { }

