module ApplicationHelper
require 'envolve_chat'
  # Return a title on a per-page basis.
  def logo
    logo = image_tag("logo-1.png", :alt => "Sample App", :class => "round") 
  end
  
  def title
    base_title = "Ruby on Rails Tutorial Sample App"
    if @title.nil?
      base_title
    else
      "#{base_title} | #{@title}"
    end
  end
  
  
end