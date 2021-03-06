
require 'pry'
require 'httparty'
require "sinatra"
require "instagram"

require_relative 'db_config'
require_relative 'models/photo'
require_relative 'models/user'

enable :sessions

helpers do

  def current_user
    User.find_by(id: session[:user_id])
  end

  def logged_in?
    !!current_user
  end

  def create_location_data(recent_media)
    output = []
    recent_media['data'].each do |media| 
      if media['location'] != nil 
      output.push(media['location'])
      end
    end
    output
  end

  def update_user_info(recent_media)
    user = current_user
    user.instagram_username = recent_media['data'].first['user']['username']
    user.profile_pic_url = recent_media['data'].first['user']['profile_picture']
    user.save
  end

  def cache_photo_data(recent_media)
    recent_media['data'].each do |media| 
      if media['location'] && media['caption'] && media['caption']['text'] && !Photo.find_by(caption: media['caption']['text'])
      photo = Photo.new
      photo.user_id = current_user.id
      photo.latitude = media['location']['latitude']
      photo.longitude = media['location']['longitude']
      photo.location_name = media['location']['name']
      photo.likes = media['likes']['count']
      photo.caption = media['caption']['text']
      photo.creation_time = media['created_time']
      photo.thumbnail_url = media['images']['thumbnail']['url']
      photo.picture_url = media['images']['standard_resolution']['url']
      photo.save
      end
    end
  end
end

get '/' do 
  erb :index
end

get '/signup' do 
  if logged_in?
    redirect '/'
  end
    erb :signup
end

post '/users' do
  unless logged_in? || User.find_by(email: params[:email])
    redirect '/'
  else
    user = User.new
    user.email = params[:email]
    user.password = params[:password]
    user.save
  end
  erb :dashboard
end

get '/about' do
  erb :about
end

get '/dashboard' do
  unless logged_in?
    redirect '/'
  end
erb :dashboard
end

get '/login' do
  erb :login
end

post '/session' do
  user = User.find_by(email: params[:email])
  if user && user.authenticate(params[:password])
  session[:user_id] = user.id
  erb :dashboard
  else 
    erb :login
  end
end

get '/oauth/callback' do
  response = HTTParty.post(
    "https://api.instagram.com/oauth/access_token",
     :body => 
     { 'client_id' => ENV['INSTAGRAM_CLIENT_ID'], 
      'client_secret' => ENV['INSTAGRAM_CLIENT_SECRET'],
      'grant_type' => 'authorization_code',
      'redirect_uri' => 'https://shrouded-badlands-24074.herokuapp.com/oauth/callback',
      'code' => params[:code].to_s
      })

  @access_token = response['access_token']
  recent_media = HTTParty.get("https://api.instagram.com/v1/users/self/media/recent/?access_token=#{@access_token}")
  p recent_media['data']
  cache_photo_data(recent_media)
  update_user_info(recent_media)
  @photo_data = Photo.where(user_id: current_user.id).pluck(:thumbnail_url, :latitude, :longitude, :caption, :likes, :creation_time, :location_name, :picture_url)
  erb :map
end



