#
# Cookbook Name:: user
# Recipe:: data_bag
#
# Copyright 2011, Fletcher Nichol
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

bag = node['user']['data_bag_name']
on_group_missing = node['user']['on_group_missing']

# Fetch the user array from the node's attribute hash. If a subhash is
# desired (ex. node['base']['user_accounts']), then set:
#
#     node['user']['user_array_node_attr'] = "base/user_accounts"
user_array = node
node['user']['user_array_node_attr'].split("/").each do |hash_key|
  user_array = user_array.send(:[], hash_key)
end

groups = {}

# only manage the subset of users defined
Array(user_array).each do |i|
  name = i.gsub(/[.]/, '-')

  u = if node['user']['data_bag_encrypted']
    Chef::EncryptedDataBagItem.load(bag, name, node['user']['data_bag_encryption_key'])
  else
    data_bag_item(bag, name)
  end

  username = u['username'] || u['id']

  user_account username do
    %w{comment uid gid home shell password system_user manage_home create_group
        ssh_keys ssh_keygen non_unique }.each do |attr|
      send(attr, u[attr]) if u[attr]
    end
    action Array(u['action']).map { |a| a.to_sym } if u['action']
  end

  unless u['groups'].nil? || u['action'] == 'remove'
    u['groups'].each do |groupname|
      groups[groupname] = [] unless groups[groupname]
      groups[groupname] += [username]
    end
  end
end

# the behaviour if a group does not exist depends on the on_group_missing attribute
# we control this by setting the action taken to operate on the groups
case on_group_missing
when 'fail'
  g_action = :modify
when 'ignore'
  g_action = :manage
when 'create'
  g_action = :create
end

groups.each do |groupname, users|
  group groupname do
    action g_action
    members users
    append true
  end
end
