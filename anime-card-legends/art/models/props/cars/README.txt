CARS
====

Drop a .glb (or .gltf) in this folder and it becomes a car you can pick
in the garage. Nothing else to edit.

  octane.glb        ->  "Octane"
  dominus_gt.glb    ->  "Dominus GT"
  battle_bus.glb    ->  "Battle Bus"

The filename is the name: underscores and dashes become spaces and it is
capitalised for the picker.

SCALE DOES NOT MATTER. Every car is measured after loading and rescaled
to the same length, so a model exported in centimetres, metres or
Blender units all end up the same size on the pitch.

WHICH WAY IT FACES DOES NOT MATTER EITHER. The model is measured and
turned so its longest horizontal axis points forwards. If a particular
car still drives backwards, open res://scenes/Car.tscn and set model_yaw
to PI - that is an extra half turn on top of the measured one.

The original art/models/props/car.glb still works and shows up in the
garage as "Standard". Move it in here and rename it if you would rather
it had a proper name.

A file whose name starts with "_" is skipped, so you can park a model
here without it joining the pool.
