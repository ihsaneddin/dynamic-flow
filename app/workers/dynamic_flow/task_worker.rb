module DynamicFlow
  class TaskWorker < ApplicationJob

    self.model = DynamicFlow::Task
    queue_as DynamicFlow.queue_name

    def start
      resource do |task|
        if task.may_start?
          task.start!
        end
      end
    end

  end
end