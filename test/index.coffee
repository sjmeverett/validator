
(require "mocha-as-generated")()
Ractive = require 'ractive'
expect = (require 'chai').expect

Validator = require '../src'


describe 'Validator', ->
  
  describe 'built-in', ->
    val = Validator.validators
    
    describe 'required validator', ->
      it 'should be invalid for undefined', ->
        expect(val.required(undefined, true).valid).to.be.false
        
      it 'should be invalid for null', ->
        expect(val.required(null, true).valid).to.be.false
        
      it 'should be invalid for empty string', ->
        expect(val.required('', true).valid).to.be.false
        
      it 'should be valid for a non-empty string', ->
        expect(val.required('a value', true).valid).to.be.true
        
      it 'should be valid for an empty string if not required', ->
        expect(val.required('', false).valid).to.be.true
      
      it 'should be valid for non-empty string when group is not set', ->
        expect(val.required('foo', 'group=value', groups: {}).valid).to.be.true
        
      it 'should be valid for empty string when group is not set', ->
        expect(val.required('', 'group=value', groups: {}).valid).to.be.true
        
      it 'should be valid for non-empty string when group is set to same value', ->
        expect(val.required('foo', 'group=value', groups: group: 'value').valid).to.be.true
        
      it 'should be invalid for non-empty string when group is set to different value', ->
        expect(val.required('foo', 'group=different', groups: group: 'value').valid).to.be.false
        
      it 'should be valid for empty string when group is set to different value', ->
        expect(val.required('', 'group=different', groups: group: 'value').valid).to.be.true
    
    
    describe 'password validator', ->
      it 'should be valid for same value', ->
        expect(val.password('password', 'password', model: get: (x) -> x).valid).to.be.true
      
      it 'should be invalid for different value', ->
        expect(val.password('password', 'foo', model: get: (x) -> x).valid).to.be.false
    
    
    describe 'moment validator', ->
      it 'should be valid for an empty value', ->
        expect(val.moment('', 'DD/MM/YYYY').valid).to.be.true
      
      it 'should be valid for a correct value', ->
        expect(val.moment('05/12/1989', 'DD/MM/YYYY').valid).to.be.true
      
      it 'should be invalid for a wrong value', ->
        expect(val.moment('fish', 'DD/MM/YYYY').valid).to.be.false
      
      it 'should coerce the value if asked', ->
        expect(val.moment('05/12/1989', format: 'DD/MM/YYYY', coerce: true).coerced.isValid).to.exist
      
      it 'should coerce to the specified format', ->
        expect(val.moment('05/12/1989', format: 'DD/MM/YYYY', coerce: 'YYYY-MM-DD').coerced).to.equal '1989-12-05'
    
    
    describe 'type validator', ->
      # strings
      it 'should be valid for string type and empty string', ->
        expect(val.type('foo', 'string', immediate: false).valid).to.be.true
      
      it 'should be invalid for string type and an integer', ->
        expect(val.type(5, 'string', immediate: false).valid).to.be.false
        
      # integers
      it 'should be valid for integer type and an empty string', ->
        expect(val.type('', 'integer', immediate: false).valid).to.be.true
      
      it 'should be valid for integer type and an integer', ->
        expect(val.type(5, 'integer', immediate: false).valid).to.be.true
      
      it 'should be invalid for integer type and a decimal', ->
        expect(val.type(5.5, 'integer', immediate: false).valid).to.be.false
      
      it 'should be valid for integer type and an integer string', ->
        v = val.type('5', 'integer', immediate: false)
        expect(v.valid).to.be.true
        expect(v.coerced).to.equal 5
      
      it 'should be invalid for integer type and a decimal string', ->
        expect(val.type('5.5', 'integer', immediate: false).valid).to.be.false
      
      it 'should be invalid for integer type and an arbitrary string', ->
        expect(val.type('foo', 'integer', immediate: false).valid).to.be.false
      
      it 'should be invalid for integer type and an integer string if immediate is true', ->
        expect(val.type('5', 'integer', immediate: true).valid).to.be.false
      
      # decimals
      it 'should be valid for decimal type and an empty string', ->
        expect(val.type('', 'decimal', immediate: false).valid).to.be.true
      
      it 'should be valid for decimal type and a decimal', ->
        expect(val.type(5.5, 'decimal', immediate: false).valid).to.be.true
      
      it 'should be valid for decimal type and a decimal string', ->
        v = val.type('5.5', 'decimal', immediate: false)
        expect(v.valid).to.be.true
        expect(v.coerced).to.equal 5.5
        
      it 'should be invalid for decimal type and an arbitrary string', ->
        expect(val.type('foo', 'decimal', immediate: false).valid).to.be.false
      
      it 'should be valid for decimal type and an integer string', ->
        expect(val.type('5', 'decimal', immediate: false).valid).to.be.true
      
       it 'should be invalid for decimal type and a decimal string if immediate is true', ->
        expect(val.type('5.5', 'decimal', immediate: true).valid).to.be.false
      
      # booleans
      it 'should be valid for boolean type and an empty string', ->
        expect(val.type('', 'boolean', immediate: false).valid).to.be.true
      
      it 'should be valid for boolean type and a boolean', ->
        expect(val.type(true, 'boolean', immediate: false).valid).to.be.true
      
      it 'should be valid for boolean type and a boolean string', ->
        v = val.type('false', 'boolean', immediate: false)
        expect(v.valid).to.be.true
        expect(v.coerced).to.be.false
      
      it 'should be invalid for boolean type and an arbitrary string', ->
        expect(val.type('foo', 'boolean', immediate: false).valid).to.be.false
      
      it 'should be invalid for boolean type and a boolean string if immediate is true', ->
        expect(val.type('true', 'boolean', immediate: true).valid).to.be.false
    
    
    describe 'positive validator', ->
      it 'should be valid for positive numbers', ->
        expect(val.positive(5).valid).to.be.true
      
      it 'should be invalid for negative numbers', ->
        expect(val.positive(-1).valid).to.be.false