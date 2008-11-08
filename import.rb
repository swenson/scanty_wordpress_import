require 'rubygems'
require 'rexml/document'
require 'time'
require 'sequel'
DB = Sequel.connect('sqlite://blog.db')
$LOAD_PATH.unshift(File.dirname(__FILE__) + '/lib')
require 'post'

if ARGV.length == 0
  puts 'I require an XML file name to be passed as an argument.'
  exit 1
end

file = File.new(ARGV[0])

# we have to hack the XML file, unfortunately, since it isn't valid
file = file.read
file.sub!(/xmlns:wp="http:\/\/wordpress.org\/export\/1.0\/"/,
         "xmlns:wp=\"http://wordpress.org/export/1.0/\"\nxmlns:excerpt=\"excerpt\"")

doc = REXML::Document.new file

# Assume that there is one channel  (FIX?)
# cycle through all of the items
doc.root.elements["channel"].elements.each("item") { |item| 
  # if it's a published post, then we import it
  # Scanty doesn't support pages or drafts yet
  if item.elements["wp:post_type"].text == "post" and
     item.elements["wp:status"].text == "publish" then

     title = item.elements["title"].text
     content = item.elements["content:encoded"].text
     time = Time.parse item.elements["wp:post_date"].text
     tags = []
     item.elements.each("category") { |cat|
       domain = cat.attribute("domain")
       if domain and domain.value == "tag"
         tags.unshift cat.text
       end
     }
     tags = tags.map { |t| t.downcase }.sort.uniq

     post = Post.new :title => title, :tags => tags, :body => content, :created_at => time, :slug => Post.make_slug(title)
     if post.save
       puts "Saved post: #{title}"
     else
       puts "ERROR! could not save post #{title}"
       exit
     end
  end
}
