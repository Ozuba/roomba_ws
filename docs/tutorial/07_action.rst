Stretch goal: an action server
==============================

*5–10 minutes, if you have time.* **You add:** ``~/rotate_absolute``, which turns the robot in
place to a heading, using ``turtlesim/action/RotateAbsolute`` (goal ``theta``, feedback
``remaining``, result ``delta``). It streams feedback, can be cancelled, and a new goal
preempts a running one.

The code
--------

Members:

.. code-block:: gdscript

   # Step 7: action
   var _rotate_server: RosActionServer
   var _rotate_goal: RosServerGoalHandle # Goal steering the robot (null = none); /cmd_vel is ignored meanwhile

Call ``_setup_actions()`` from ``_ready()``, and add this helper next to ``_publish_odometry()``:

.. code-block:: gdscript

   ## Heading in the odom frame (rad, counterclockwise). Godot's yaw about +Y is ROS's yaw about +Z.
   func _odom_yaw() -> float:
       return (_odom_origin.affine_inverse() * global_transform).basis.get_euler().y

The server:

.. code-block:: gdscript

   func _setup_actions() -> void:
       _rotate_server = _node.create_action_server("~/rotate_absolute",
               "turtlesim/action/RotateAbsolute", _execute_rotate)


   ## Turns in place to an absolute heading in the odom frame. The execute callback runs on the
   ## main thread, so it advances one physics frame at a time with await instead of blocking.
   func _execute_rotate(goal: RosServerGoalHandle) -> void:
       _rotate_goal = goal # A newer goal takes over from one still running (see the loop below)
       var target: float = goal.get_goal().theta
       var start := _odom_yaw()
       var feedback := goal.create_feedback()
       var result := goal.create_result()
       while true:
           result.delta = wrapf(_odom_yaw() - start, -PI, PI)
           if _rotate_goal != goal: # Preempted by a newer goal
               goal.abort(result)
               return
           if goal.is_cancel_requested():
               _finish_rotation()
               goal.canceled(result)
               return
           var error := wrapf(target - _odom_yaw(), -PI, PI)
           if absf(error) < 0.01:
               break
           # Proportional turn, with a floor so it doesn't crawl the last few degrees
           var turn := clampf(4.0 * error, -max_angular_speed, max_angular_speed)
           drive(0.0, signf(turn) * maxf(absf(turn), 0.15))
           feedback.remaining = error
           goal.publish_feedback(feedback)
           await get_tree().physics_frame

       _finish_rotation()
       result.delta = wrapf(_odom_yaw() - start, -PI, PI)
       goal.succeed(result)


   func _finish_rotation() -> void:
       stop()
       _rotate_goal = null

Finally, keep ``/cmd_vel`` and its watchdog out of the way while a goal is steering. In
``_on_cmd_vel``:

.. code-block:: gdscript

       if _rotate_goal:
           return

at the top, and in ``_physics_process`` change the watchdog condition to:

.. code-block:: gdscript

       if not _rotate_goal and _now_s() - _last_cmd_time > cmd_vel_timeout:

How it works
------------

**Goals are accepted automatically.** Each one reaches ``_execute_rotate`` as a
``RosServerGoalHandle`` on the main thread. ``create_action_server`` also takes an optional
``goal_callback`` if you want to reject goals up front.

``await`` **instead of a loop that blocks.** A GDScript function that ``await``\ s becomes a
coroutine. ``await get_tree().physics_frame`` suspends it until the next physics step, so the
game keeps rendering, the physics keeps running, and the robot actually turns while the
"loop" runs. Each pass through the loop is one control step: read the heading, command a
turn, publish feedback. A blocking ``while`` here would freeze the whole game.

**Every goal ends exactly once.** ``succeed()``, ``abort()`` or ``canceled()``, each with a
result made by ``create_result()``. Cancel requests are accepted automatically, and your loop
notices them through ``is_cancel_requested()``.

**Preemption** falls out of coroutines. A second goal starts a second ``_execute_rotate`` that
overwrites ``_rotate_goal``. On its next step, the first coroutine sees it's no longer in
charge and aborts itself.

Check it
--------

.. code-block:: console

   $ ros2 action send_goal --feedback /roomba/rotate_absolute turtlesim/action/RotateAbsolute "{theta: 3.14}"
   Goal accepted with ID: 3f9c…
   Feedback:
       remaining: 1.5707
   ...
   Result:
       delta: 1.5687
   Goal finished with status: SUCCEEDED

Slow it down with ``ros2 param set /roomba max_angular_speed 0.3`` and press :kbd:`Ctrl+C`
mid-turn: the CLI cancels the goal and the robot stops where it is. (Jazzy's CLI may then
print ``Executor is already spinning``. That's a quirk of ``ros2 action``, and the cancel has
already gone through.)
