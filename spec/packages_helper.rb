# PackagesHelper
#
module PackagesHelper
  class << self
    # Full list of available st2 packages
    def full_list
      @full_list ||= (ENV['ST2_PACKAGES'] || '').split
    end

    # Package list to be tested
    def list
      @list ||= (ENV['PACKAGE_LIST'] || '').split
    end

    def essential_directories
      %w( /etc/st2
          /etc/logrotate.d
          /var/log/st2
          /opt/stackstorm/packs )
    end

    # System services user except st2action runner (which is runas root)
    def service_user
      'st2'
    end

    # Stanley is an action execution user and sudoer
    def stanley_user
      'stanley'
    end
  end
end
