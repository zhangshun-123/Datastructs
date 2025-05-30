import moonbit/rand
import moonbit/core/compare { Compare }
import moonbit/core/option { Option, Some, None }
import moonbit/core/clone { Clone }

// NodeId is an index into the `nodes` array in SkipList
type NodeId = Int;
const NIL_ID: NodeId = 0; // Represents end-of-list or unlinked

// 跳表节点结构
pub struct Node[K, V] {
  key: K,
  value: V,
  forwards: Array[NodeId], // Index to next node at each level
}

// 跳表主体
pub struct SkipList[K, V] {
  nodes: Array[Option[Node[K, V]]], // Node storage
  head_id: NodeId,                  // ID of the dummy head node (e.g., 1)
  max_level: Int,                   // Max possible level for any node
  p: Double,                        // Probability for level increase
  
  free_node_ids: Array[NodeId],     // Stack of available indices in `nodes`
  current_nodes_count: Int,         // Number of actual data nodes
  // Default key/value for head node, passed during construction
}

// Constructor: Initializes SkipList
pub fn new[K, V](
  max_level: Int, 
  p: Double, 
  default_key: K, // Used for the head node
  default_value: V, // Used for the head node
  initial_capacity: Int // Estimated max number of nodes to preallocate
) -> SkipList[K, V] {
  // nodes array: index 0 is NIL_ID, head is at index 1, data nodes from index 2 onwards
  let total_slots = initial_capacity + 1; // +1 for the head node
  let mut nodes_storage = Array::make(total_slots, None);
  
  let head_id: NodeId = 1; // Head node is at index 1
  if head_id >= total_slots {
    // Or handle error: initial_capacity must be at least 1 for the head node
    // For simplicity, assume initial_capacity is reasonably sized.
    // This assertion would be better.
    // assert(initial_capacity >= 1, "Initial capacity too small for head node");
  }

  let head_forwards = Array::make(max_level, NIL_ID);
  nodes_storage[head_id] = Some(Node { 
    key: default_key, 
    value: default_value, 
    forwards: head_forwards,
  });
  
  let mut free_ids = Array::empty();
  for i = head_id + 1; i < total_slots; i = i + 1 {
    free_ids.push(i);
  }
  // free_ids.reverse(); // If pop order matters (e.g., for contiguous allocation)

  SkipList {
    nodes: nodes_storage,
    head_id,
    max_level,
    p,
    free_node_ids: free_ids,
    current_nodes_count: 0,
  }
}

// Gets a free NodeId from the pool
fn get_free_node_id[K, V](mut sl: SkipList[K, V]) -> (SkipList[K,V], Option[NodeId]) {
  // TODO: Implement array growth if free_node_ids is empty
  let opt_id = sl.free_node_ids.pop();
  (sl, opt_id)
}

// Releases a NodeId back to the pool
fn release_node_id[K, V](mut sl: SkipList[K, V], node_id: NodeId) {
  sl.nodes[node_id] = None; // Clear the slot
  sl.free_node_ids.push(node_id); // Add index to free list
  sl
}

// Randomly generates node level
fn random_level(p: Double, max_level: Int) -> Int {
  var level = 1
  while rand::float64() < p && level < max_level {
    level = level + 1
  }
  level
}

// Inserts a key-value pair
pub fn insert[K: Compare + Clone, V](mut sl: SkipList[K, V], key: K, value: V) -> SkipList[K,V] {
  var update = Array::make(sl.max_level, NIL_ID); // Stores NodeId
  var current_id = sl.head_id;

  for i = sl.max_level - 1; i >= 0; i = i - 1 {
    // Ensure current_id is valid and node exists before unwrapping
    while let Some(current_node) = sl.nodes[current_id] {
      let next_id = current_node.forwards[i];
      if next_id != NIL_ID {
        if let Some(next_node) = sl.nodes[next_id] {
           if next_node.key < key {
            current_id = next_id;
            // continue inner while loop with new current_id
           } else {
            break; // Found position at this level or key is greater/equal
           }
        } else { break; } // Should not happen: next_id points to None
      } else {
        break; // End of list at this level
      }
    }
    update[i] = current_id;
  }

  // Check if key already exists (optional, could update value or disallow duplicates)
  // let potential_existing_id = sl.nodes[update[0]].unwrap().forwards[0];
  // if potential_existing_id != NIL_ID && sl.nodes[potential_existing_id].unwrap().key == key {
  //   // Update value or return error/status
  //   return sl; 
  // }

  let lvl = random_level(sl.p, sl.max_level);
  let (mut sl_after_get_id, opt_new_node_id) = get_free_node_id(sl);
  sl = sl_after_get_id;

  if let Some(new_node_id) = opt_new_node_id {
    var new_node_data = Node { key, value, forwards: Array::make(lvl, NIL_ID) };
    for i = 0; i < lvl; i = i + 1 {
      let prev_update_node_id = update[i];
      if prev_update_node_id != NIL_ID { // Ensure prev_update_node_id is valid
        if let Some(mut prev_update_node_val) = sl.nodes[prev_update_node_id].take() {
          new_node_data.forwards[i] = prev_update_node_val.forwards[i];
          prev_update_node_val.forwards[i] = new_node_id;
          sl.nodes[prev_update_node_id] = Some(prev_update_node_val);
        }
      }
    }
    sl.nodes[new_node_id] = Some(new_node_data);
    sl.current_nodes_count = sl.current_nodes_count + 1;
  } else {
    // Handle no free nodes (e.g., error, resize array)
    println("Error: No free nodes available for insertion.");
  }
  sl
}

// Finds the value for a key
pub fn get[K: Compare, V: Clone](sl: &SkipList[K, V], key: K) -> Option[V] {
  var current_id = sl.head_id;
  for i = sl.max_level - 1; i >= 0; i = i - 1 {
     while let Some(current_node) = sl.nodes[current_id] {
        let next_id = current_node.forwards[i];
        if next_id != NIL_ID {
            if let Some(next_node) = sl.nodes[next_id] {
                if next_node.key < key {
                    current_id = next_id;
                } else {
                    break;
                }
            } else { break; } // Should not happen
        } else {
            break;
        }
     }
  }
  
  // Check the node at level 0
  if let Some(node_before_target) = sl.nodes[current_id] {
    let final_candidate_id = node_before_target.forwards[0];
    if final_candidate_id != NIL_ID {
      if let Some(final_node) = sl.nodes[final_candidate_id] {
        if final_node.key == key {
          return Some(final_node.value.clone());
        }
      }
    }
  }
  None
}

// Removes a key
pub fn remove[K: Compare + Clone, V](mut sl: SkipList[K, V], key: K) -> (SkipList[K,V], Bool) {
  var update = Array::make(sl.max_level, NIL_ID);
  var current_id = sl.head_id;

  for i = sl.max_level - 1; i >= 0; i = i - 1 {
    while let Some(current_node) = sl.nodes[current_id] {
        let next_id = current_node.forwards[i];
        if next_id != NIL_ID {
            if let Some(next_node) = sl.nodes[next_id] {
                if next_node.key < key {
                    current_id = next_id;
                } else {
                    break;
                }
            } else { break; }
        } else {
            break;
        }
    }
    update[i] = current_id;
  }

  let target_id_opt = if let Some(node_before_target) = sl.nodes[update[0]] {
    node_before_target.forwards[0]
  } else { NIL_ID };


  if target_id_opt != NIL_ID {
    if let Some(target_node_val) = sl.nodes[target_id_opt] { // Check if target_id is valid
        if target_node_val.key == key {
        for i = 0; i < target_node_val.forwards.length(); i = i + 1 {
            let prev_update_node_id = update[i];
            if prev_update_node_id != NIL_ID { // Ensure prev_update_node_id is valid
                if let Some(mut prev_update_node_val) = sl.nodes[prev_update_node_id].take() {
                    if prev_update_node_val.forwards[i] == target_id_opt {
                        prev_update_node_val.forwards[i] = target_node_val.forwards[i];
                    }
                    sl.nodes[prev_update_node_id] = Some(prev_update_node_val);
                }
            }
        }
        sl = release_node_id(sl, target_id_opt);
        sl.current_nodes_count = sl.current_nodes_count - 1;
        return (sl, true);
        }
    }
  }
  (sl, false)
}

fn main -> Unit {
  var sl = new(4, 0.5, 0, 0, 100); // MaxLevel 4, Prob 0.5, Head (0,0), Capacity 100 nodes

  sl = insert(sl, 1, 100);
  sl = insert(sl, 2, 200);
  sl = insert(sl, 0, 50); // Test key smaller than head's default if not careful
  sl = insert(sl, 10, 1000);


  println("get 1 = ${get(&sl, 1)}");
  println("get 2 = ${get(&sl, 2)}");
  println("get 0 = ${get(&sl, 0)}");
  println("get 10 = ${get(&sl, 10)}");
  println("get 3 (non-existent) = ${get(&sl, 3)}");

  var removed_status;
  (sl, removed_status) = remove(sl, 2);
  println("remove 2 status: ${removed_status}");
  println("get 2 after remove = ${get(&sl, 2)}");
  
  (sl, removed_status) = remove(sl, 0);
  println("remove 0 status: ${removed_status}");
  println("get 0 after remove = ${get(&sl, 0)}");

  (sl, removed_status) = remove(sl, 15); // Non-existent
  println("remove 15 status: ${removed_status}");
}

test "skiplist basic operations" {
  var sl = new(3, 0.5, -1, -1, 50); // Head key -1 to be smaller than test keys

  assert_eq!(get(&sl, 5), None);

  sl = insert(sl, 5, 500);
  assert_eq!(get(&sl, 5), Some(500));

  sl = insert(sl, 2, 200);
  sl = insert(sl, 8, 800);

  assert_eq!(get(&sl, 2), Some(200));
  assert_eq!(get(&sl, 8), Some(800));

  var removed;
  (sl, removed) = remove(sl, 5);
  assert_eq!(removed, true);
  assert_eq!(get(&sl, 5), None);

  (sl, removed) = remove(sl, 99); // Remove non-existent
  assert_eq!(removed, false);

  assert_eq!(get(&sl, 2), Some(200)); // Check other nodes are fine
  assert_eq!(get(&sl, 8), Some(800));
}

```// filepath: /Users/xunyoyo/Desktop/PICT/moon_datastructs/datastructs/src/skiplist.mbt
import moonbit/rand
import moonbit/core/compare { Compare }
import moonbit/core/option { Option, Some, None }
import moonbit/core/clone { Clone }

// NodeId is an index into the `nodes` array in SkipList
type NodeId = Int;
const NIL_ID: NodeId = 0; // Represents end-of-list or unlinked

// 跳表节点结构
pub struct Node[K, V] {
  key: K,
  value: V,
  forwards: Array[NodeId], // Index to next node at each level
}

// 跳表主体
pub struct SkipList[K, V] {
  nodes: Array[Option[Node[K, V]]], // Node storage
  head_id: NodeId,                  // ID of the dummy head node (e.g., 1)
  max_level: Int,                   // Max possible level for any node
  p: Double,                        // Probability for level increase
  
  free_node_ids: Array[NodeId],     // Stack of available indices in `nodes`
  current_nodes_count: Int,         // Number of actual data nodes
  // Default key/value for head node, passed during construction
}

// Constructor: Initializes SkipList
pub fn new[K, V](
  max_level: Int, 
  p: Double, 
  default_key: K, // Used for the head node
  default_value: V, // Used for the head node
  initial_capacity: Int // Estimated max number of nodes to preallocate
) -> SkipList[K, V] {
  // nodes array: index 0 is NIL_ID, head is at index 1, data nodes from index 2 onwards
  let total_slots = initial_capacity + 1; // +1 for the head node
  let mut nodes_storage = Array::make(total_slots, None);
  
  let head_id: NodeId = 1; // Head node is at index 1
  if head_id >= total_slots {
    // Or handle error: initial_capacity must be at least 1 for the head node
    // For simplicity, assume initial_capacity is reasonably sized.
    // This assertion would be better.
    // assert(initial_capacity >= 1, "Initial capacity too small for head node");
  }

  let head_forwards = Array::make(max_level, NIL_ID);
  nodes_storage[head_id] = Some(Node { 
    key: default_key, 
    value: default_value, 
    forwards: head_forwards,
  });
  
  let mut free_ids = Array::empty();
  for i = head_id + 1; i < total_slots; i = i + 1 {
    free_ids.push(i);
  }
  // free_ids.reverse(); // If pop order matters (e.g., for contiguous allocation)

  SkipList {
    nodes: nodes_storage,
    head_id,
    max_level,
    p,
    free_node_ids: free_ids,
    current_nodes_count: 0,
  }
}

// Gets a free NodeId from the pool
fn get_free_node_id[K, V](mut sl: SkipList[K, V]) -> (SkipList[K,V], Option[NodeId]) {
  // TODO: Implement array growth if free_node_ids is empty
  let opt_id = sl.free_node_ids.pop();
  (sl, opt_id)
}

// Releases a NodeId back to the pool
fn release_node_id[K, V](mut sl: SkipList[K, V], node_id: NodeId) {
  sl.nodes[node_id] = None; // Clear the slot
  sl.free_node_ids.push(node_id); // Add index to free list
  sl
}

// Randomly generates node level
fn random_level(p: Double, max_level: Int) -> Int {
  var level = 1
  while rand::float64() < p && level < max_level {
    level = level + 1
  }
  level
}

// Inserts a key-value pair
pub fn insert[K: Compare + Clone, V](mut sl: SkipList[K, V], key: K, value: V) -> SkipList[K,V] {
  var update = Array::make(sl.max_level, NIL_ID); // Stores NodeId
  var current_id = sl.head_id;

  for i = sl.max_level - 1; i >= 0; i = i - 1 {
    // Ensure current_id is valid and node exists before unwrapping
    while let Some(current_node) = sl.nodes[current_id] {
      let next_id = current_node.forwards[i];
      if next_id != NIL_ID {
        if let Some(next_node) = sl.nodes[next_id] {
           if next_node.key < key {
            current_id = next_id;
            // continue inner while loop with new current_id
           } else {
            break; // Found position at this level or key is greater/equal
           }
        } else { break; } // Should not happen: next_id points to None
      } else {
        break; // End of list at this level
      }
    }
    update[i] = current_id;
  }

  // Check if key already exists (optional, could update value or disallow duplicates)
  // let potential_existing_id = sl.nodes[update[0]].unwrap().forwards[0];
  // if potential_existing_id != NIL_ID && sl.nodes[potential_existing_id].unwrap().key == key {
  //   // Update value or return error/status
  //   return sl; 
  // }

  let lvl = random_level(sl.p, sl.max_level);
  let (mut sl_after_get_id, opt_new_node_id) = get_free_node_id(sl);
  sl = sl_after_get_id;

  if let Some(new_node_id) = opt_new_node_id {
    var new_node_data = Node { key, value, forwards: Array::make(lvl, NIL_ID) };
    for i = 0; i < lvl; i = i + 1 {
      let prev_update_node_id = update[i];
      if prev_update_node_id != NIL_ID { // Ensure prev_update_node_id is valid
        if let Some(mut prev_update_node_val) = sl.nodes[prev_update_node_id].take() {
          new_node_data.forwards[i] = prev_update_node_val.forwards[i];
          prev_update_node_val.forwards[i] = new_node_id;
          sl.nodes[prev_update_node_id] = Some(prev_update_node_val);
        }
      }
    }
    sl.nodes[new_node_id] = Some(new_node_data);
    sl.current_nodes_count = sl.current_nodes_count + 1;
  } else {
    // Handle no free nodes (e.g., error, resize array)
    println("Error: No free nodes available for insertion.");
  }
  sl
}

// Finds the value for a key
pub fn get[K: Compare, V: Clone](sl: &SkipList[K, V], key: K) -> Option[V] {
  var current_id = sl.head_id;
  for i = sl.max_level - 1; i >= 0; i = i - 1 {
     while let Some(current_node) = sl.nodes[current_id] {
        let next_id = current_node.forwards[i];
        if next_id != NIL_ID {
            if let Some(next_node) = sl.nodes[next_id] {
                if next_node.key < key {
                    current_id = next_id;
                } else {
                    break;
                }
            } else { break; } // Should not happen
        } else {
            break;
        }
     }
  }
  
  // Check the node at level 0
  if let Some(node_before_target) = sl.nodes[current_id] {
    let final_candidate_id = node_before_target.forwards[0];
    if final_candidate_id != NIL_ID {
      if let Some(final_node) = sl.nodes[final_candidate_id] {
        if final_node.key == key {
          return Some(final_node.value.clone());
        }
      }
    }
  }
  None
}

// Removes a key
pub fn remove[K: Compare + Clone, V](mut sl: SkipList[K, V], key: K) -> (SkipList[K,V], Bool) {
  var update = Array::make(sl.max_level, NIL_ID);
  var current_id = sl.head_id;

  for i = sl.max_level - 1; i >= 0; i = i - 1 {
    while let Some(current_node) = sl.nodes[current_id] {
        let next_id = current_node.forwards[i];
        if next_id != NIL_ID {
            if let Some(next_node) = sl.nodes[next_id] {
                if next_node.key < key {
                    current_id = next_id;
                } else {
                    break;
                }
            } else { break; }
        } else {
            break;
        }
    }
    update[i] = current_id;
  }

  let target_id_opt = if let Some(node_before_target) = sl.nodes[update[0]] {
    node_before_target.forwards[0]
  } else { NIL_ID };


  if target_id_opt != NIL_ID {
    if let Some(target_node_val) = sl.nodes[target_id_opt] { // Check if target_id is valid
        if target_node_val.key == key {
        for i = 0; i < target_node_val.forwards.length(); i = i + 1 {
            let prev_update_node_id = update[i];
            if prev_update_node_id != NIL_ID { // Ensure prev_update_node_id is valid
                if let Some(mut prev_update_node_val) = sl.nodes[prev_update_node_id].take() {
                    if prev_update_node_val.forwards[i] == target_id_opt {
                        prev_update_node_val.forwards[i] = target_node_val.forwards[i];
                    }
                    sl.nodes[prev_update_node_id] = Some(prev_update_node_val);
                }
            }
        }
        sl = release_node_id(sl, target_id_opt);
        sl.current_nodes_count = sl.current_nodes_count - 1;
        return (sl, true);
        }
    }
  }
  (sl, false)
}

fn main -> Unit {
  var sl = new(4, 0.5, 0, 0, 100); // MaxLevel 4, Prob 0.5, Head (0,0), Capacity 100 nodes

  sl = insert(sl, 1, 100);
  sl = insert(sl, 2, 200);
  sl = insert(sl, 0, 50); // Test key smaller than head's default if not careful
  sl = insert(sl, 10, 1000);


  println("get 1 = ${get(&sl, 1)}");
  println("get 2 = ${get(&sl, 2)}");
  println("get 0 = ${get(&sl, 0)}");
  println("get 10 = ${get(&sl, 10)}");
  println("get 3 (non-existent) = ${get(&sl, 3)}");

  var removed_status;
  (sl, removed_status) = remove(sl, 2);
  println("remove 2 status: ${removed_status}");
  println("get 2 after remove = ${get(&sl, 2)}");
  
  (sl, removed_status) = remove(sl, 0);
  println("remove 0 status: ${removed_status}");
  println("get 0 after remove = ${get(&sl, 0)}");

  (sl, removed_status) = remove(sl, 15); // Non-existent
  println("remove 15 status: ${removed_status}");
}

test "skiplist basic operations" {
  var sl = new(3, 0.5, -1, -1, 50); // Head key -1 to be smaller than test keys

  assert_eq!(get(&sl, 5), None);

  sl = insert(sl, 5, 500);
  assert_eq!(get(&sl, 5), Some(500));

  sl = insert(sl, 2, 200);
  sl = insert(sl, 8, 800);

  assert_eq!(get(&sl, 2), Some(200));
  assert_eq!(get(&sl, 8), Some(800));

  var removed;
  (sl, removed) = remove(sl, 5);
  assert_eq!(removed, true);
  assert_eq!(get(&sl, 5), None);

  (sl, removed) = remove(sl, 99); // Remove non-existent
  assert_eq!(removed, false);

  assert_eq!(get(&sl, 2), Some(200)); // Check other nodes are fine
  assert_eq!(get(&sl, 8), Some(800));
}
