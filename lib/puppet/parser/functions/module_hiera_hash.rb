require 'deep_merge'
require 'hiera_puppet'
require 'puppet/parser/scope'

module Puppet::Parser::Functions
  newfunction(:module_hiera_hash, :type => :rvalue, :arity => -2, :doc => <<-EOS
    Merge data in the returned classes for the hiera lookup, this means it will traverse
    the returned classes assigned to the node for the necessary hiera data
    klass is defined inside hiera i.e.
    hierarchy:
      - "modules/%{module_name}/%{klass}"
    this means it will look for the relevant class.yaml dependency within the module_name for
    the lookup and merge the results and return it so we only gather data relevant to the classes
    the node has for the dependencies on the module
    EOS
  ) do |*args|

    merged_hash = Hash.new
    if Puppet::Node.indirection.find(self['::fqdn']).classes.empty?
      key, default, override = HieraPuppet.parse_args(args)
      class_list = HieraPuppet.lookup("classes", default, self, override, :array)
    else
      class_list = Puppet::Node.indirection.find(self['::fqdn']).classes
    end
    if class_list.empty?
      key, default, override = HieraPuppet.parse_args(args)
      merged_hash = HieraPuppet.lookup(key, default, self, override, :hash)
    else
      class_list.each do |k, _|
        begin
          elevel = self.ephemeral_level
          self.ephemeral_from({'klass'=>k})
          key, default, override = HieraPuppet.parse_args(args)
          hiera_out = HieraPuppet.lookup(key, default, self, override, :hash)
          merged_hash.deep_merge(hiera_out)
        ensure
          self.unset_ephemeral_var(elevel)
        end
      end
    end
    merged_hash
  end
end
    
