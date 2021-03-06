using concurrent::ActorPool
using afConcurrent::SynchronizedState

** Provides 'synchronized' multi-thread access to a mutable 'Buf'.
** 
** 'SynchronizedBuf' creates a 'Buf' in its own thread and provides access to it via the 
** *read* and *write* methods, and complementary 'InStream' and 'OutStream' implementations. 
** 
** 'SynchronizedBuf' is different to the default 'Buf.toImmutable()' instance because 
** 'SynchronizedBuf' is mutable, designed to be constantly written to by one thread / stream,
** and constantly read by anther.  
** 
** pre>
** .--->--->---                  --->--->---
** | Producer  |      Sync      | Consumer  |
** ▲  Thread   ▼ ---> Buf  <--> ▲  Thread   ▼
** |   Loop    |               |   Loop    |
**  ---<---<---                  ---<---<---
** <pre
** 
** Note that 'SynchronizedBuf' grows unbounded. Until, that is, reading catches up with the 
** writing; at which point the internal Buf is cleared and reset to initial capacity.
** 
** See [Threaded Streams]`http://fantom.org/forum/topic/2586` on the Fantom forum for the initial design.
const class SynchronizedBuf {
	private const SynchronizedState threadState
	
	new make(ActorPool actorPool, Int capacity := 1024) {
		threadState = SynchronizedState(actorPool) |->Obj| { SynchronizedBufState(capacity) }
	}

	** Creates and returns a thread safe 'OutStream' wrapper for this 'Buf'.
	** 'OutStream' instances should be cached for re-use. 
	** 
	** Note you need to call 'flush()' to make data available to the 'InStream'. 
	OutStream out() {
		ThreadedOutStream(this)
	}
	
	** Creates and returns a thread safe 'InStream' wrapper for this 'Buf'. 
	** 'InStream' instances should be cached for re-use. 
	InStream in() {
		ThreadedInStream(this)
	}
	
	** Write a byte to the output stream.
	** 
	** This method returns immediately, with the processing happening in the Buf thread.
	This write(Int b) {
		threadState.async |SynchronizedBufState state| {
			state.write(b)
		}
		return this
	}
	
	** Write 'n' bytes from the given 'Buf' at it's current position to the output stream.
	** If 'n' is defaulted to 'buf.remaining()', then the entire buffer is drained to the output stream.
	** 
	** This method return immediately, with the processing happening in the Buf thread.
	** 
	** Due to the use of 'Buf.toImmutable()' the given 'Buf' is cleared / invalidated upon return.
	This writeBuf(Buf buf, Int n := buf.remaining) {
		threadState.async |SynchronizedBufState state| {
			state.writeBuf(buf, n)
		}
		return this
	}

	** Return the number of bytes available on the input stream without blocking.
	** Return zero if no bytes available or unknown.
	Int avail() {
		threadState.sync |SynchronizedBufState state -> Int| {
			state.avail
		}
	}
	
	** Read the next unsigned byte from the input stream.
	** Return 'null' if at end of stream.
	Int? read() {
		threadState.sync |SynchronizedBufState state -> Int?| {
			state.read
		}
	}
	
	** Attempt to read the next n bytes.
	** Note this method may not read the full number of n bytes.
	Buf readBuf(Int n) {
		threadState.sync |SynchronizedBufState state -> Buf| {
			state.readBuf(n)
		}
	}
	
	** Pushback a byte so that it is the next byte to be read.
	** There is a finite limit to the number of bytes which may be pushed back.
	Void unread(Int b) {
		threadState.sync |SynchronizedBufState state| {
			state.unread(b)
		}
	}
	
	** Attempt to skip 'n' number of bytes.  Return the number of bytes
	** actually skipped which may be equal to or lesser than 'n'.
	Int skip(Int n) {
		threadState.sync |SynchronizedBufState state -> Int| {
			state.skip(n)
		}
	}
	
	** Return the total number of bytes in the buffer. This is NOT the same as 'avail()'.
	** 
	** The internal buffer forever expands until the contents have been read, then it is cleared. 
	Int size() {
		threadState.sync |SynchronizedBufState state -> Int| {
			state.size
		}
	}

	@NoDoc
	override Str toStr() {
		threadState.sync |SynchronizedBufState state -> Str| {
			"SynchronizedBuf - size=${state.size}, pos=${state.pos}"
		}
	}
}

internal class SynchronizedBufState {
	private Int capactity
	private Buf	buf	:= Buf()
	
	new make(Int capactity) {
		this.capactity = capactity
	}
	
	Void write(Int b) {
		pos := buf.pos
		buf.seek(buf.size)
		buf.out.write(b)
		buf.seek(pos)
	}
	
	Void writeBuf(Buf b, Int n := b.remaining) {
		if (n <= 0) return
		pos := buf.pos
		buf.seek(buf.size)
		buf.out.writeBuf(b, n)
		buf.seek(pos)
	}

	Int avail() {
		buf.in.avail
	}
	
	Int? read() {
		val := buf.in.read
		clear
		return val
	}
	
	Buf readBuf(Int n) {
		b := Buf()
		buf.in.readBuf(b, n)
		clear
		return b.toImmutable
	}
	
	Void unread(Int b) {
		buf.in.unread(b)
	}
	
	Int skip(Int n) {
		val := buf.in.skip(n)
		clear
		return val
	}
	
	Int pos() {
		buf.pos
	}
	
	Int size() {
		buf.size
	}
	
	private Void clear() {
		if (avail == 0) {
			buf.clear
			buf.capacity = capactity
		}
	}
}

internal class ThreadedOutStream : OutStream {
	private Buf				buf
	private SynchronizedBuf	threadBuf

	new make(SynchronizedBuf threadBuf) : super.make(null) {
		this.buf 		= Buf()
		this.threadBuf	= threadBuf
	}
	
	** Write a byte to the output stream.
	** 
	** Call 'flush()' to commit data to the main Actor thread.
	override This write(Int byte) {
		this.buf.write(byte)
		return this
	}

	** Write n bytes from the specified Buf at it's current position to
	** the output stream. 
	** 
	** Call 'flush()' to commit data to the main Actor thread.
	override This writeBuf(Buf buf, Int n := buf.remaining) {
		this.buf.writeBuf(buf, n)
		return this
	}

	** Flush the stream so any buffered bytes are written out.  
	override This flush() {
		threadBuf.writeBuf(this.buf.toImmutable)
		this.buf.clear
		return this
	}

	** Does nothing and returns true.
	override Bool close() {
		true
	}
}


internal class ThreadedInStream : InStream {
	private SynchronizedBuf threadBuf
	
	new make(SynchronizedBuf threadBuf) : super.make(null) {
		this.threadBuf = threadBuf
	}
	
	** Return the number of bytes available on input stream without
	** blocking.  Return zero if no bytes available or it is unknown.
	override Int avail() {
		threadBuf.avail
	}
	
	** Read the next unsigned byte from the input stream.
	override Int? read() {
		threadBuf.read		
	}
	
	** Attempt to read the next n bytes into the Buf at it's current
	** position.  The buffer will be grown as needed.  Return the number
	** of bytes read and increment buf's size and position accordingly.
	** 
	** Note this method may not read the full number of n bytes, use
	** `readBufFully` if you must block until all n bytes read.
	override Int? readBuf(Buf buf, Int n) {
		b := threadBuf.readBuf(n)
		s := b.size
		buf.writeBuf(b)
		return s
	}
	
	** Pushback a byte so that it is the next byte to be read.  There
	** is a finite limit to the number of bytes which may be pushed
	** back.  Return this.
	override This unread(Int b) {
		threadBuf.unread(b)
		return this
	}
	
	** Does nothing and returns true.
	override Bool close() {
		true
	}
	
	** Attempt to skip 'n' number of bytes.  Return the number of bytes
	** actually skipped which may be equal to or lesser than n.
	override Int skip(Int n) {
		threadBuf.skip(n)
	}
}
