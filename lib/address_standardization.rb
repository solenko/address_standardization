# address_standardization: A tiny Ruby library to quickly standardize a postal address.
# Copyright (C) 2008-2010 Elliot Winkler. Released under the MIT license.

require 'mechanize'

require 'address_standardization/ruby_ext'
require 'address_standardization/class_level_inheritable_attributes'
        
require 'address_standardization/address'
require 'address_standardization/abstract_service'
require 'address_standardization/melissa_data'
require 'address_standardization/google_maps'

module AddressStandardization
  class << self
    attr_accessor :test_mode
    alias_method :test_mode?, :test_mode
    
    attr_accessor :debug_mode
    alias_method :debug_mode?, :debug_mode
    
    def debug(*args)
      puts(*args) if debug_mode?
    end
  end
  self.test_mode = false
  self.debug_mode = $DEBUG || ENV["DEBUG"] || false
end