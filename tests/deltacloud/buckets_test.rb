#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.  The
# ASF licenses this file to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance with the
# License.  You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
# License for the specific language governing permissions and limitations
# under the License.

$:.unshift File.join(File.dirname(__FILE__), '..')
require "deltacloud/test_setup.rb"

BUCKETS = "/buckets"

def small_blob_file
 File.new(File::join(File::dirname(__FILE__),"test_blob_small.png"))
end

def large_blob_file
 File.new(File::join(File::dirname(__FILE__),"test_blob_large.png"))
end

describe 'Deltacloud API buckets collection' do
  include Deltacloud::Test::Methods

  need_collection :buckets

  #make sure we have at least one bucket and blob to test
  begin
    @@my_bucket = random_name
    @@my_blob = random_name
    res = post(BUCKETS, :name=>@@my_bucket)
    unless res.code == 201
      raise Exception.new("Failed to create bucket #{@@my_bucket}")
    end

    res = put("#{BUCKETS}/#{@@my_bucket}/#{@@my_blob}", "This is the test blob content",
           {:content_type=>"text/plain", "X-Deltacloud-Blobmeta-Version"=>"1.0",
            "X-Deltacloud-Blobmeta-Author"=>"herpyderp"})
    unless res.code == 200
      raise Exception.new("Failed to create blob #{@@my_blob}")
    end
  end

  # delete the bucket/blob we created for the tests
  MiniTest::Unit.after_tests {
    res = delete("/buckets/#{@@my_bucket}/#{@@my_blob}")
    unless res.code == 204
      raise Exception.new("Failed to delete blob #{@@my_blob}")
    end
    res = delete("/buckets/#{@@my_bucket}")
    unless res.code == 204
      raise Exception.new("Failed to delete bucket #{@@my_bucket}")
    end
  }

  it 'must advertise the buckets collection in API entrypoint' do

    res = get("/").xml
    (res/'api/link[@rel=buckets]').wont_be_empty
  end

  it 'must require authentication to access the "bucket" collection' do
    proc {  get(BUCKETS, :noauth => true) }.must_raise RestClient::Request::Unauthorized
  end

  it 'should respond with HTTP_OK when accessing the :buckets collection with authentication' do
    res = get(BUCKETS)
    res.code.must_equal 200
  end

  it 'should be possible to create bucket with POST /api/buckets and delete it with DELETE /api/buckets/:id' do
    bucket_name = random_name
    #create bucket
    res = post(BUCKETS, :name=>bucket_name)
    #check response
    res.code.must_equal 201
    res.xml.xpath("//bucket/name").text.must_equal bucket_name
    res.xml.xpath("//bucket").size.must_equal 1
    res.xml.xpath("//bucket")[0][:id].must_equal bucket_name
    #GET bucket
    res = get(BUCKETS+"/"+bucket_name)
    res.code.must_equal 200
    #DELETE bucket
    res = delete(BUCKETS+"/"+bucket_name)
    res.code.must_equal 204
  end

  it 'should be possible to create large blob with PUT /api/buckets/:id/blob_id (STREAM)' do
    skip "Streaming PUT for blobs not supported by driver #{api.driver} currently running at #{api.url}" if api.driver == "mock"
    blob_name = random_name
    #using @@my_bucket which we know exists
    res = put("#{BUCKETS}/#{@@my_bucket}/#{blob_name}", large_blob_file,
           {:content_type=>"image/png", "X-Deltacloud-Blobmeta-Createdfor"=>"putblobtest",
            "X-Deltacloud-Blobmeta-Author"=>"herpyderp", "X-Deltacloud-Blobmeta-Type"=>"largeblob"})
    res.code.must_equal 200
    #GET it
    res = get(BUCKETS+"/"+@@my_bucket+"/"+blob_name)
    res.code.must_equal 200
    #delete it:
    res = delete("/buckets/#{@@my_bucket}/#{blob_name}")
    res.code.must_equal 204
  end

  it 'should be possible to create small blob with PUT /api/buckets/:id/blob_id (NO STREAM)' do
    blob_name = random_name
    #using @@my_bucket which we know exists
    res = put("#{BUCKETS}/#{@@my_bucket}/#{blob_name}", small_blob_file,
           {:content_type=>"image/png", "X-Deltacloud-Blobmeta-Createdfor"=>"putblobtest",
            "X-Deltacloud-Blobmeta-Author"=>"herpyderp", "X-Deltacloud-Blobmeta-Type"=>"smallbob"})
    res.code.must_equal 200
    #GET it
    res = get(BUCKETS+"/"+@@my_bucket+"/"+blob_name)
    res.code.must_equal 200
    #delete it:
    res = delete("/buckets/#{@@my_bucket}/#{blob_name}")
    res.code.must_equal 204
  end

  it 'should be possible to create blob with POST /api/buckets/:id' do
    blob_name = random_name
    res = post("#{BUCKETS}/#{@@my_bucket}", {:blob_id => blob_name, :blob_data => small_blob_file, :multipart => true, :meta_params => 2, :meta_name1=>"Author", :meta_value1 => "herpyderp", :meta_name2 => "Type", :meta_value2 => "formPostedBlob"})
    res.code.must_equal 201
    #GET it
    res = get(BUCKETS+"/"+@@my_bucket+"/"+blob_name)
    res.code.must_equal 200
    #delete it:
    res = delete("/buckets/#{@@my_bucket}/#{blob_name}")
    res.code.must_equal 204
  end

  it 'should be possible to get blob metadata with HEAD /api/buckets/:id/blob_id' do
    res = head("#{BUCKETS}/#{@@my_bucket}/#{@@my_blob}")
    res.code.must_equal 204
    res.headers.keys.must_include :x_deltacloud_blobmeta_version
    res.headers.keys.must_include :x_deltacloud_blobmeta_author
  end

  it 'should be possible to update blob metadata with POST /api/buckets/:id/blob' do
    res = post("#{BUCKETS}/#{@@my_bucket}/#{@@my_blob}", "", {"X-Deltacloud-Blobmeta-Version"=>"2.5",
               "X-Deltacloud-Blobmeta-Author"=>"derpyherpy", "X-Deltacloud-Blobmeta-Updated"=>"true"})
    res.code.must_equal 204
    res.headers.keys.must_include :x_deltacloud_blobmeta_version
    res.headers.keys.must_include :x_deltacloud_blobmeta_author
    res.headers.keys.must_include :x_deltacloud_blobmeta_updated
  end

  it 'should be possible to GET blob data with GET /api/buckets/:id/blob/content' do
    res = get("#{BUCKETS}/#{@@my_bucket}/#{@@my_blob}/content")
    res.code.must_equal 200
    res.must_equal "This is the test blob content"
  end

  describe "with feature bucket_location" do
    need_feature :buckets, :bucket_location

    it 'should be possible to specify location for POST /api/buckets if bucket_location feature' do
      bucket_name = random_name
      location = api.bucket_locations.choice #random element
      raise Exception.new("Unable to get location constraint from config.yaml for driver #{api.driver} - check configuration") unless location
      res = post(BUCKETS, {:name=>bucket_name, :bucket_location=>location}, {:accept=>:xml})
      res.code.must_equal 201
      res.xml.xpath("//bucket/name").text.must_equal bucket_name
      res.xml.xpath("//bucket").size.must_equal 1
      res.xml.xpath("//bucket")[0][:id].must_equal bucket_name
      #GET bucket
      res = get(BUCKETS+"/"+bucket_name)
      res.code.must_equal 200
      #DELETE bucket
      res = delete(BUCKETS+"/"+bucket_name)
      res.code.must_equal 204
    end
  end

  it 'should support the JSON media type' do
    res = get(BUCKETS, :accept=>:json)
    res.code.must_equal 200
    res.headers[:content_type].must_equal 'application/json'
    assert_silent {JSON.parse(res)}
  end

  it 'must include the ETag in HTTP headers' do
    res = get(BUCKETS)
    res.headers[:etag].wont_be_nil
  end

  it 'must have the "buckets" element on top level' do
    res = get(BUCKETS, :accept=>:xml)
    res.xml.root.name.must_equal 'buckets'
  end

  it 'must have some "bucket" elements inside "buckets"' do
    res = get(BUCKETS, :accept=>:xml)
    (res.xml/'buckets/bucket').wont_be_empty
  end

  it 'must provide the :id attribute for each bucket in collection' do
    res = get(BUCKETS, :accept=>:xml)
    (res.xml/'buckets/bucket').each do |r|
      r[:id].wont_be_nil
    end
  end

  it 'must include the :href attribute for each "bucket" element in collection' do
    res = get(BUCKETS, :accept=>:xml)
    (res.xml/'buckets/bucket').each do |r|
      r[:href].wont_be_nil
    end
  end

  it 'must use the absolute URL in each :href attribute' do
    res = get(BUCKETS, :accept=>:xml)
    (res.xml/'buckets/bucket').each do |r|
      r[:href].must_match /^http/
    end
  end

  it 'must have the URL ending with the :id of the bucket' do
    res = get(BUCKETS, :accept=>:xml)
    (res.xml/'buckets/bucket').each do |r|
      r[:href].must_match /#{r[:id]}$/
    end
  end

  it 'must have the "name" element defined for each bucket in collection' do
    res = get(BUCKETS, :accept => :xml)
    (res.xml/'buckets/bucket').each do |r|
      (r/'name').wont_be_nil
      (r/'name').wont_be_empty
    end
  end

  it 'must have the "size" element defined for each bucket in collection' do
    res = get(BUCKETS, :accept => :xml)
    (res.xml/'buckets/bucket').each do |r|
      (r/'size').wont_be_nil
      (r/'size').wont_be_empty
    end
  end

  it 'must return 200 OK when following the URL in bucket element' do
    res = get(BUCKETS, :accept => :xml)
    (res.xml/'buckets/bucket').each do |r|
      bucket_res = get r[:href]
      bucket_res.code.must_equal 200
    end
  end

  it 'must have the "name" element for the bucket and it should match with the one in collection' do
    res = get(BUCKETS, :accept => :xml)
    (res.xml/'buckets/bucket').each do |r|
      bucket = get(BUCKETS+"/#{r[:id]}", :accept=>:xml)
      (bucket.xml/'name').wont_be_empty
      (bucket.xml/'name').first.text.must_equal((r/'name').first.text)
    end
  end

  it 'all "blob" elements for the bucket should match the ones in collection' do
    res = get(BUCKETS, :accept => :xml)
    (res.xml/'buckets/bucket').each do |r|
      bucket = get(BUCKETS+"/#{r[:id]}", :accept=>:xml)
      (bucket.xml/'bucket/blob').each do |b|
        b[:id].wont_be_nil
        b[:href].wont_be_nil
        b[:href].must_match /^http/
        b[:href].must_match /#{r[:id]}\/#{b[:id]}$/
      end
    end
  end

  it 'must allow to get all blobs details and the details should be set correctly' do
    res = get(BUCKETS, :accept => :xml)
    (res.xml/'buckets/bucket').each do |r|
      bucket = get(BUCKETS+"/#{r[:id]}", :accept=>:xml)
      (bucket.xml/'bucket/blob').each do |b|
        blob = get(BUCKETS+"/#{r[:id]}/#{b[:id]}", :accept=>:xml)
        blob.xml.root.name.must_equal 'blob'
        blob.xml.root[:id].must_equal b[:id]
        (blob.xml/'bucket').wont_be_empty
        (blob.xml/'bucket').size.must_equal 1
        (blob.xml/'bucket').first.text.wont_be_nil
        (blob.xml/'bucket').first.text.must_equal r[:id]
        (blob.xml/'content_length').wont_be_empty
        (blob.xml/'content_length').size.must_equal 1
        (blob.xml/'content_length').first.text.must_match /^(\d+)$/
        (blob.xml/'content_type').wont_be_empty
        (blob.xml/'content_type').size.must_equal 1
        (blob.xml/'content_type').first.text.wont_be_nil
        (blob.xml/'last_modified').wont_be_empty
        (blob.xml/'last_modified').size.must_equal 1
        (blob.xml/'last_modified').first.text.wont_be_empty
        (blob.xml/'content').wont_be_empty
        (blob.xml/'content').size.must_equal 1
        (blob.xml/'content').first[:rel].wont_be_nil
        (blob.xml/'content').first[:rel].must_equal 'blob_content'
        (blob.xml/'content').first[:href].wont_be_nil
        (blob.xml/'content').first[:href].must_match /^http/
        (blob.xml/'content').first[:href].must_match /\/content$/
      end
    end
  end

end
