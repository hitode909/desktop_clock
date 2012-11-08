#! /usr/bin/env ruby
require 'bundler/setup'
require 'open-uri'
require 'json'
require 'digest/sha1'
require 'rmagick'
require 'tempfile'

module Mirror
  def self.file(url)
    local_path = "/tmp/#{ Digest::SHA1.hexdigest(url.to_s)}"

    unless File.exists? local_path
      warn "get #{url}"
      open(local_path, 'w+'){ |f|
        f.write open(url).read
      }
    end
    local_path
  end
end

class ImageSearch
  API_KEY = 'AIzaSyDmqM8S4LStx_1B_-7uZfecle1IXDhNZUc'
  ENDPOINT = 'https://ajax.googleapis.com/ajax/services/search/images'

  attr_reader :items

  def initialize(query)
    @query = query

  end

  def search
    params = {
      :key => API_KEY,
      :v => '1.0',
      :save => 'off',
      :rsz => 8,
      :q => @query,
    }

    uri = ENDPOINT + '?' + URI.encode_www_form(params)

    @result = JSON.parse(open(Mirror.file(uri)).read)
  end

  def urls
    search unless @result

    @result['responseData']['results'].map{ |item|
      item['unescapedUrl']
    }
  end

  def sample
    urls.sample
  end
end

class Clock
  def initialize
    @numbers = (0..9).map{ |i| ImageSearch.new(i.to_s) }
  end

  def process
    now = Time.now

    base = Magick::Image.new(1440, 900){
      self.background_color = 'white'
    }

    ("%02d %02d" % [ now.hour, now.min]).split(//).each_with_index{ |letter, index|
      next if letter == ' '

      number = letter.to_i

      image = Magick::ImageList.new Mirror.file(@numbers[number].sample)

      base = append(base, image, index * number_width, 0)
    }

    path = "/tmp/#{Time.now.to_i.to_s}.png"

    base.write(path)

    set_desktop(path)
  end

  def append(base, image, x, y)
    base.composite(image.resize(number_width, number_height), x, y, Magick::OverCompositeOp)
  end

  def set_desktop(path)
    script = <<-SCRIPT
    tell application "System Events" to set picture of every desktop to file "#{path.gsub('/', ':')}"
    SCRIPT

    system 'osascript', '-e', script
  end

  def number_width
    1440 / 5
  end

  def number_height
    900
  end
end

clock = Clock.new

last_minute = nil
loop {
  if Time.now.min != last_minute
    puts Time.now
    last_minute = Time.now.min
    begin
      clock.process
    rescue => error
      warn error
    end
  end
  sleep 1
}
