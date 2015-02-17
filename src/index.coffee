
((factory) ->
  if typeof exports is 'object'
    # node.js-type environment
    moment = require 'moment'
    module.exports = factory(moment)
  else if typeof define is 'function' and define.amd
    # amd (requirejs etc)
    define ['moment'], factory
  else if window?
    # browser
    window.Validator = factory(window.moment)
  
)((moment) ->
  global = class Validator
    ##
    # Creates a new validator
    # @param model (optional)
    # @param basePath (optional)
    # @param rules
    constructor: () ->
      # get the arguments
      switch arguments.length
        when 3
          [@model, @basePath, @rules] = arguments
        when 2
          @rules = arguments[1]

          if typeof arguments[0] == 'string'
            @basePath = arguments[0] + '.'
          else
            @basePath = ''
            @model = arguments[0]
        when 1
          @rules = arguments[0]
          @basePath = ''
        else
          throw new Error('wrong number of arguments')

      # set some defaults
      @validators = Validator.validators
      @errorSuffix = 'Msg'
      @enabled = true

      # set up observers if necessary
      if @model?.observe?
        @observeModel()
    
    
    ##
    # Set up observers on model
    # 
    observeModel: ->
      for rulepath in @rules
        @model.observe rulepath, (newValue, oldValue, keypath) =>
            if @enabled
              @validateKeypath newValue, keypath, result, @rules[rulepath]
          ,
            init: false
    
    
    ##
    # Sets whether or not the observing validation is enabled
    #
    enable: (value) ->
      @enabled = value
      # clear the error messages
      @model.set(@basePath + keypath + @errorSuffix) for keypath in @rules

    
    ##
    # Validates either the model given in the constructor or as an argument
    # @param model (optional) the model to validate
    # @returns a validation object
    validate: (model) ->
      result =
        valid: true
        model: model or @model
        errors: new ObjectModel()
        data: new ObjectModel()
        groups: []
        immediate: model?
      
      # wrap POJOs in an ObjectModel
      if not (result.model.get and result.model.set)
        result.model = new ObjectModel result.model
      
      # polyfill models without expandKeypath method (i.e., ractive)
      if not result.model.expandKeypath
        model.expandKeypath = ObjectModel.prototype.expandKeypath

      # validate the model
      for keypath, rules of @rules
        @validateWildcardKeypath @basePath + keypath, result, rules

      return {}=
        valid: result.valid
        errors: result.errors.model
        data: result.data.get(@basePath)
    
    
    ##
    # Validates a keypath possibly containing a wildcard
    #
    validateWildcardKeypath: (keypath, result, rules) ->
      paths = result.model.expandKeypath keypath
      
      for path in paths
        @validateKeypath result.model.get(path), path, result, rules
    

    ##
    # Validates a specific keypath
    #
    validateKeypath: (value, keypath, result, rules) ->
      # work through each rule
      for rule, ruleValue of rules
        # if it's not a known rule, but it does define a function, use that function
        if not @validators.hasOwnProperty(rule)
          if typeof ruleValue is 'function'
            validator = ruleValue
          else
            throw new Error "validator #{rule} not defined"
        else
          validator = @validators[rule]

        # validate
        validation = validator.call(this, value, ruleValue, result)

        if validation.valid
          # clear the error message if necessary
          result.model.set(keypath + @errorSuffix, undefined) if not result.immediate
        else
          # not valid, set the error message and break
          result.valid = false
          result.errors.set keypath, validation.error
          result.model.set(keypath + @errorSuffix, validation.error) if not result.immediate
          break

      # if it was valid, set the corresponding result.data
      if result.valid
        result.data.set(keypath, if validation.coerced? then validation.coerced else value)


    ##
    # Define the built-in validators
    #
    @validators:
      ##
      # A 'required' validator, with support for groups
      #
      required: (value, required, result) ->
        # check if it's actually required
        if required
          if typeof required == 'string'
            # it's a require group, rather than a straight true or false
            [match, groupName, groupValue] = required.match(/([^\.]+)=(.+)/) or []

            if not match
              throw new Error 'invalid require rule: ' + required

            group = result.groups[groupName]

            if not value? or value == ''
              # value doesn't exist, should it?
              if group == groupValue
                # it should
                return valid: false, error: 'required'
              else
                # it shouldn't
                return valid: true
            else
              # value exists, should it?
              if group == undefined
                # first time we've encountered this group
                # make the rest of the things in the group required
                result.groups[groupName] = groupValue
                return valid: true
              else if group == groupValue
                # it should exist, and it does
                return valid: true
              else
                # it shouldn't exist
                return valid: false, error: 'not required'
          else
            # it's a straight true or false
            if not value? or value == ''
              return valid: false, error: 'required'
            else
              return valid: true
        else
          # not required, always valid
          return valid: true


      ##
      # A validator for 'confirm password' fields
      #
      password: (value, otherField, result) ->
        if value == result.model.get(otherField)
          return valid: true
        else
          return valid: false, error: 'passwords must match'


      ##
      # Checks that the input matches a given moment.js format, with support for
      # coercing to a moment object or a different format
      #
      moment: (value, format) ->
        # allow coerce format to be specified
        if typeof format != 'string'
          {format, coerce} = format

        # don't attempt anything if it's empty
        if not value? or value == ''
          return valid: true

        # check if it's valid
        m = moment(value, format, true)

        if m.isValid()
          if coerce == true
            return valid: true, coerced: m
          else if typeof coerce == 'string'
            return valid: true, coerced: m.format(coerce)
          else
            return valid: true
        else
          return valid: false, error: 'must be ' + format


      ##
      # Checks that the input is the specified data type - will attempt to coerce
      # from string for model validation
      #
      type: (value, type, result) ->
        # don't attempt anything if there isn't a value
        if not value?
          return valid: true

        # string
        if type == 'string'
          if typeof value != 'string'
            return valid: false, error: 'must be a string'
          else
            return valid: true

        # integer
        else if type == 'integer'
          if (typeof value == 'number' and (value % 1) != 0) or
              (typeof value != 'number' and result.immediate) or
              (value? and value != '' and not /^(\-|\+)?([0-9]+)$/.test(value))
            return valid: false, error: 'must be a whole number'
          else
            return valid: true, coerced: Number(value)

        # decimal
        else if type == 'decimal'
          if (typeof value != 'number' and result.immediate) or
              (value? and value != '' and not /^(\-|\+)?([0-9]+(\.[0-9]+)?)$/.test(value))
            return valid: false, error: 'must be a decimal'
          else
            return valid: true, coerced: Number(value)

        # boolean
        else if type == 'boolean'
          if (typeof value != 'boolean' and result.immediate) or
              (value? and value != '' and not /^(true|false)$/.test(value))
            return valid: false, error: 'must be a boolean'
          else
            return valid: true, coerced: value == 'true'

        # unknown type
        else
          throw new Error('unknown data type ' + type)


      ##
      # Checks that the input is positive
      #
      positive: (value, type) ->
        if value >= 0
          return valid: true
        else
          return valid: false, error: 'must be positive'


  global.ObjectModel = class ObjectModel
    constructor: (model) ->
      @model = model or {}


    ##
    # Gets the value(s) at a keypath
    #
    get: (keypath) ->
      # expand wild cards etc to get a list of keypaths
      paths = @expandKeypath keypath

      # map the list of keypaths to the values therein
      results = paths.map (keypath) =>
        {object, child} = getObj @model, keypath
        return object[child]

      # return the list of values, or if it's just one, return it on its own
      if paths.length > 1
        return results
      else
        return results[0]


    ##
    # Sets the value at a keypath
    set: (keypath, value) ->
       # expand wild cards etc to get a list of keypaths
      paths = @expandKeypath keypath

      # set the value at each keypath to the given value
      for keypath in paths
        {object, child} = getObj @model, keypath
        object[child] = value


    ##
    # Expands paths with wildcards to a list of paths
    # 
    expandKeypath: (keypath, parent, paths) ->
      paths = paths or []

      # match wildcards
      [match, path, remainder] = keypath.match(/^([^\*]*)\.\*(\..*)?$/) or []

      if match
        # wildcard present, keep recursing
        @expandKeypath(k + remainder, (parent or '') + path, paths) for k in @get(path)
      else
        # no wildcard, add to the list of paths
        keypath = parent + '.' + keypath if parent
        paths.push(keypath)

      return paths


    ##
    # Gets a reference to a keypath location
    #
    getObj: (obj, keypath) ->
      pos = keypath.indexOf '.'

      if pos == -1
        # simple path, return the reference
        return {}=
          object: obj
          child: keypath
      else
        # path with at least 1 child, recurse
        # match the parent, immediate child, and remaining keypaths
        [match, parent, remainder, child] = keypath.match(/^([^\.]+)\.(([^\.]+).*)$/)

        # if it doesn't exist, create it
        if not obj.hasOwnProperty parent
          obj[parent] = if isNaN(parseInt(child)) then {} else []

        return getObj obj[parent], remainder
  
  return global
)