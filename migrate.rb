# Migrates time from CSV exported by Harvest

# It's in the format:
# Date, Client, Project, Project Code, Task, Notes, Hours, Hours Rounded, Billable?, Invoiced?, First Name, Last Name, Department, Employee?, Hourly Rate, Billable Amount, Currency

require 'yaml'
require 'csv'
require 'freshbooks'

config = YAML::load_file(File.join(__dir__, 'config.yml'))
freshbooks_subdomain = config['freshbooks_subdomain']
freshbooks_auth_token = config['freshbooks_auth_token']

FreshBooks::Base.establish_connection(freshbooks_subdomain, freshbooks_auth_token)

class FreshBooks::Task
  def to_xml(elem_name = nil)
    # The root element is the class name underscored
    elem_name ||= self.class.to_s.split('::').last.underscore
    root = REXML::Element.new(elem_name)

    # Only add rate and id to root element
    element = FreshBooks::XmlSerializer.to_node('rate', self.rate, 'fixnum')
    root.add_element(element) if element != nil

    # Add ID
    element = FreshBooks::XmlSerializer.to_node('task_id', self.task_id, 'fixnum')
    root.add_element(element) if element != nil

    root.to_s
  end
end

$clients = FreshBooks::Client.list
$projects = FreshBooks::Project.list
$tasks = FreshBooks::Task.list
$me_id = FreshBooks::Staff.list[0].staff_id

def client_for_name(name)
    match = nil

    $clients.each do |client|
        if client.organization == name
            match = client
            break
        end
    end

    return match
end

def project_for_name(name, rate, client_id)
    match = nil

    $projects.each do |project|
        if project.name == name
            match = project
            break
        end
    end

    if match == nil
        # project doesn't exist, so create it
        project = FreshBooks::Project.new
        project.name = name
        project.rate = rate
        project.client_id = client_id
        project.bill_method = 'project-rate'

        puts "Create project #{name}"
        if project.create
            # update cached projects list
            $projects = FreshBooks::Project.list

            # return new project
            return project_for_name(name, rate, client_id)
        else
            puts "Failed to create project: #{project.error_msg}"
        end
    end

    return match
end

def task_for_name(name, billable)
  match = nil

  $tasks.each do |task|
    if task.name == name
      match = task
      break
    end
  end

  if match == nil
    puts "Can't find task with name #{task.name}"

    # task doesn't exist, so create it
    task = FreshBooks::Task.new
    task.name = name
    task.billable = billable

    puts "Create task #{name}"
    if task.create
      # update cached tasks list
      $tasks = FreshBooks::Task.list

      # return new project
      return task_for_name(name, billable)
    else
      puts "Failed to create task: #{task.error_msg}"
    end
  end

  return match
end

def import
    puts "My Staff ID: #{$me_id}"

    CSV.foreach(File.join(__dir__, "data.csv"), :encoding => "utf-8") do |row|
        date = Date.strptime(row[0], "%d/%m/%Y")
        client_name = row[1]
        project_name = row[2]
        project_rate = row[14]
        task_name = row[4]
        task_billable = (row[8] == "Yes") ? true : false
        client = client_for_name(client_name)
        hours = row[6].to_f
        notes = row[5]

        if client != nil
            # get or create the project
            project = project_for_name(project_name, project_rate, client.client_id)
            if project == nil
                puts "No project (#{project_name}) found or created."
                return
            end

            # get or create the task
            task = task_for_name(task_name, task_billable)
            if task == nil
                puts "No task (#{task_name}) found or created."
                return
            end

            # ADDING TASKS DOESNT SEEM TO WORK
            # SO INSTEAD THEY ARE ADDED MANUALLY
            # AFTER THE PROJECT IS CREATED

           # make sure the project has this task assigned
           has_task = false
           if project.tasks != nil
               project.tasks.each do |task|
                   if task.name == task_name
                       has_task = true
                       break
                   end
               end
           end

           # if the task is not assigned, assign it
           if has_task == false
               project.tasks.push(task)
               if project.update
                   puts "Added task #{task.name} to project #{project.name}"
               else
                   puts "Failed to add task #{task.name} to project #{project.name} because: #{project.error_msg}"
                   puts "Attempted XML: #{project.to_xml}"
                   return
               end
           end

            # project.tasks.push(task)
            # if project.update
            #     puts "Added task #{task.name} to project #{project.name}"
            # else
            #     puts "Failed to add task #{task.name} to project #{project.name} because: #{project.error_msg}"
            #     puts "Attempted XML: #{project.to_xml}"
            #     return
            # end

            # last thing is to create a time entry
            entry = FreshBooks::TimeEntry.new
            entry.notes = notes
            entry.hours = hours
            entry.date = date
            entry.project_id = project.project_id
            entry.task_id = task.task_id
            entry.staff_id = $me_id

            if entry.create
                puts "Created entry for #{client_name} – #{project_name} – #{task_name}: #{hours} on #{date}"
            else
                puts "FAILED to create entry for #{client_name} – #{project_name} – #{task_name}: #{hours} on #{date} BECAUSE: #{entry.error_msg}"
                return
            end
        else
            puts "Client '#{client_name}' not found, not importing."
        end
    end
end

import()
