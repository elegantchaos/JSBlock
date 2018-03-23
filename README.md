# JSBlock

This is a proof of concept for a generic stand-in block for use with JavaScript.

I wrote it with Sketch in mind, but there are other use cases.

The block can be obtained from JavaScript by calling:

```javascript
JSBlock.blockWithSignatureFunction(signature, function);
```

where `signature` is the @encode-style signature of the block, and `function` is a javascript function.

You then pass the block to whatever API needs it. When that API calls the block, your javascript function will be invoked.

For example:

```javascript

// get a block with the signature double(^MyBlock)(double,double), 
// which calls a function to multiply two doubles
var block = JSBlock.blockWithSignatureFunction("d24@?0d8d16", function(x,y) {
    return x * y;
});
```



### How It Works

I'm using some internal knowledge about the block ABI to make a fake block which will call a custom function when it is invoked. 

Hat-tip to Mike Ash for some useful information that pointed me in the right direction. 

We then use knowledge of the signature to pull the arguments out one by one, and use JavaScriptCore to turn them into JS values and to then call the supplied Javascript function with them.

Finally we capture the javascript return value, turn it back into whatever the block is supposed to be returning, and return it.

### Using It

This is standalone code - it's not linked into Mocha, or Sketch, or anything else.

To use it with Sketch right now you need to be able to include the JSBlock source into your own custom Objective-C library which you then need to load from the plugin.

I've tested it as a proof of concept in a javascript context, but not currently within Sketch.

### Caveats

The code is rough at the moment, un-optimised, hacks all over the place, and generally not production-ready.

Fairly obviously, the JavaScript context that your function was defined in still has to exist at the point that the block is called.

Memory management may be a little sketchy. I know that JavaScriptCore itself originally had an implementation of something like
this, but [it was removed](https://bugs.webkit.org/show_bug.cgi?id=107836) due to problems with the memory management. I suspect that was
because they were trying to solve every case in a way which we're not doing here, but it's still a cause for caution.

The proof of concept handles accepting and returning some basic types: int, double, bool, string, CGRect, CGPoint, CGSize, NSRange and arbitrary objects. 

It doesn't yet deal with the general case of structures. In theory that support for them should be possible, but it requires a bit more hackery, particularly when
they are returned from the block.

I might try to add some of them, but it involves quite a bit of effort, I've got quite a few other distractions. and I did this mostly to show that it can be done! 

I'm not really looking for paid work right now but if you're desperate enough to get this working that you want to pay me to do it, I might be persuadable, so by
all means get in touch.



