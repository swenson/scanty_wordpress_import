require 'rubygems'
require 'rexml/document'
require 'time'
require 'sequel'

# Change this to load the DB for your blog
DB = Sequel.connect('sqlite://blog.db')

$LOAD_PATH.unshift(File.dirname(__FILE__) + '/lib')
require 'post'

# This allows us to overwrite the primary key, so that you
# can keep the same links for your comments
Post.unrestrict_primary_key

if ARGV.length == 0
  puts 'I require an XML file name to be passed as an argument.'
  exit 1
end

file = File.new(ARGV[0])

# we have to hack the XML file, unfortunately, since it isn't valid
# at least, for Wordpress 2.6.2
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
     
		post_id = item.elements["wp:post_id"].text.to_i
    title = item.elements["title"].text
    content = item.elements["content:encoded"].text
    time = Time.parse item.elements["wp:post_date"].text
		# post_parent = item.elements["wp:post_parent"].text.to_i
    tags = []
    item.elements.each("category") { |cat|
      domain = cat.attribute("domain")
      if domain and domain.value == "tag"
        tags.unshift cat.text
      end
    }
    tags = tags.map { |t| t.downcase }.sort.uniq

    post = Post.new :id => post_id, :title => title, :tags => tags, :body => content, :created_at => time, :slug => Post.make_slug(title)
    if post.save
      puts "Saved post: id ##{post.id} #{title}"
    else
      puts "ERROR! could not save post #{title}"
      exit
    end
  end
}
