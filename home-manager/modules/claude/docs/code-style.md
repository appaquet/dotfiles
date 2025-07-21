
# General code style guidelines

* Comments should be clear and concise, explaining the "why" rather than the "what". They shouldn't
  be obvious or redundant over the code. Ex:

 ```go
  // Adding user to the database
  db.AddUser(user) // 🛑 bad

  // Since a user may or may not exist yet, we need to use save instead of add and update
  db.SaveUser(user) // ✅ good
  ```

* When the code has a complex chunks of logic that cannot be easily split, it's ok to use comments
  to delimitate and describe the what of that block. Ex:

  ```go
  
  // Handle ABC
  ...
  ...
  ...

  // Handle XYZ
  ...
  ...
  ...

  ```

