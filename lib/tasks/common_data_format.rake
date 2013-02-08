require "rubygems"

# Add the local gems dir if found within the app root; any dependencies loaded
# hereafter will try to load from the local gems before loading system gems.
if (local_gem_dir = File.join(File.dirname(__FILE__), '..', '..', 'gems')) && $BUNDLE.nil?
  $BUNDLE = true; Gem.clear_paths; Gem.path.unshift(local_gem_dir)
end

require "merb-core"

# this loads all plugins required in your init file so don't add them
# here again, Merb will do it for you
Merb.start_environment(:environment => ENV['MERB_ENV'] || 'development')

namespace :mostfit do

  namespace :highmark do

    desc "This rake task generates the Common Data Format for integration with Credit Bureau"
    task :generate, :from_date, :to_date, :frequency_identifier do |t, args|
      USAGE = <<USAGE_TEXT
rake mostfit:highmark:generate[<to_date>,<from_date>,'frequency_identifier']
NOTE: Make sure there are no spaces after and before the comma separating the two arguments.
Both to_date and from_date has to be supplied. Also frequency_identifier is also necessary to be supplied.
The format for the date is DD-MM-YYYY. The date has to be enclosed in single quotes. For 6th August 2011 it shall be '06-08-2011'.
Enter 'monthly' if you want to generate the Credit Bureau files for a month or enter 'weekly' if you want to run this report for a week
EXAMPLE: rake mostfit:highmark:generate['13-07-2011','monthly']
         rake mostfit:highmark:generate['13-07-2011','06-07-2011','weekly']
USAGE_TEXT

      if args[:to_date].nil?
        p USAGE
      elsif args[:from_date].nil?
        p USAGE
      elsif args[:frequency_identifier].nil?
        p USAGE
      elsif (args[:to_date] and args[:from_date] and args[:frequency_identifier])
        to_date = Date.strptime(args[:to_date], "%d-%m-%Y")
        from_date = Date.strptime(args[:from_date], "%d-%m-%Y")
        frequency_identifier = args[:frequency_identifier]
        t1 = Time.now
        report = Highmark::CommonDataFormat.new({:frequency_identifier => frequency_identifier}, {:to_date => to_date, :from_date => from_date}, User.first)
        data = report.generate
        folder = File.join(Merb.root, "doc", "csv", "reports")
        t2 = Time.now
        puts
        puts "It took #{t2-t1} seconds to generate this report."
        puts "The files are stored at #{folder}"
      else
        p USAGE
      end
    end

  end

end
