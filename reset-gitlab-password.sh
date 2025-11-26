#!/bin/bash
# Reset or create GitLab root user

docker exec gitlab gitlab-rails runner "
user = User.find_by(username: 'root')
password = 'GitLab@Test2024!Secure'

if user.nil?
  puts 'Creating root user...'
  user = User.new(
    username: 'root',
    email: 'admin@example.com',
    name: 'Administrator',
    admin: true,
    password: password,
    password_confirmation: password
  )
  user.skip_confirmation!
  user.save!
  puts '========================================='
  puts 'Root user created successfully!'
  puts 'Username: root'
  puts 'Password: GitLab@Test2024!Secure'
  puts '========================================='
else
  puts 'Resetting root password...'
  user.password = password
  user.password_confirmation = password
  user.save!
  puts '========================================='
  puts 'Password reset successfully!'
  puts 'Username: root'
  puts 'Password: GitLab@Test2024!Secure'
  puts '========================================='
end
"
