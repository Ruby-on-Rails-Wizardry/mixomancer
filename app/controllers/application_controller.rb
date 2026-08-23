class ApplicationController < ActionController::Base
  # Household phones include Opera Android, which reports OPR/8x — below Rails
  # :modern (Opera 106+). Do not 406 family browsers on the LAN.

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
end
