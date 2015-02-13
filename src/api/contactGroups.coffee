ContactGroup = require('../model/contactGroups').ContactGroup
Q = require 'q'
logger = require 'winston'
authorisation = require './authorisation'

utils = require "../utils"

###############################
#     Adds a contactGroup     #
###############################
exports.addContactGroup = ->
  # Must be admin
  if authorisation.inGroup('admin', @authenticated) is false
    utils.logAndSetResponse this, 'forbidden', "User #{this.authenticated.email} is not an admin, API access to addContactGroup denied.", 'info'
    return

  contactGroupData = @request.body

  try
    contactGroup = new ContactGroup(contactGroupData)
    result = yield Q.ninvoke(contactGroup, 'save')
    
    utils.logAndSetResponse this, 'created', "Contact Group successfully created", 'info'
  catch err
    utils.logAndSetResponse this, 'bad request', "Could not add a contact group via the API: #{err}", 'error'



#############################################################
#     Retrieves the details of a specific contact group     #
#############################################################
exports.getContactGroup = (contactGroupId) ->
  # Must be admin
  if authorisation.inGroup('admin', @authenticated) is false
    utils.logAndSetResponse this, 'forbidden', "User #{this.authenticated.email} is not an admin, API access to getContactGroup denied.", 'info'
    return

  contactGroupId = unescape(contactGroupId)

  try
    result = yield ContactGroup.findById(contactGroupId).exec()

    if result == null
      @body = "Contact Group with id '#{contactGroupId}' could not be found."
      @status = 'not found'
    else
      @body = result
  catch err
    utils.logAndSetResponse this, 'internal server error', "Could not find Contact Group by id '#{contactGroupId}' via the API: #{err}", 'error'



##################################
#     Updates a contactGroup     #
##################################
exports.updateContactGroup = (contactGroupId) ->
  # Must be admin
  if authorisation.inGroup('admin', @authenticated) is false
    utils.logAndSetResponse this, 'forbidden', "User #{this.authenticated.email} is not an admin, API access to updateContactGroup denied.", 'info'
    return

  contactGroupId = unescape(contactGroupId)
  contactGroupData = @request.body

  # Ignore _id if it exists, a user shouldnt be able to update the internal id
  if contactGroupData._id
    delete contactGroupData._id

  try
    yield ContactGroup.findByIdAndUpdate(contactGroupId, contactGroupData).exec()
    @body = "Successfully updated contact group."
    logger.info "User #{@authenticated.email} updated contact group with id #{contactGroupId}"
  catch err
    utils.logAndSetResponse this, 'internal server error', "Could not update Contact Group by id #{contactGroupId} via the API: #{err}", 'error'




##################################
#     Removes a contactGroup     #
##################################
exports.removeContactGroup = (contactGroupId) ->
  # Must be admin
  if authorisation.inGroup('admin', @authenticated) is false
    utils.logAndSetResponse this, 'forbidden', "User #{this.authenticated.email} is not an admin, API access to removeContactGroup denied.", 'info'
    return

  contactGroupId = unescape (contactGroupId)

  try
    yield ContactGroup.findByIdAndRemove(contactGroupId).exec()
    @body = "Successfully removed contact group with ID '#{contactGroupId}'"
    logger.info "User #{@authenticated.email} removed contact group with id #{contactGroupId}"
  catch err
    utils.logAndSetResponse this, 'internal server error', "Could not remove Contact Group by id {contactGroupId} via the API: #{err}", 'error'




#######################################
#     Retrieves all contactGroups     #
#######################################
exports.getContactGroups = ->
  # Must be admin
  if authorisation.inGroup('admin', @authenticated) is false
    utils.logAndSetResponse this, 'forbidden', "User #{this.authenticated.email} is not an admin, API access to getContactGroups denied.", 'info'
    return

  try
    @body = yield ContactGroup.find().exec();
  catch err
    utils.logAndSetResponse this, 'internal server error', "Could not fetch all Contact Group via the API: #{err}", 'error'