

// NodeId is an index into the `nodes` array in LruCache
typealias NodeId = Int

pub struct Node[K, V] {
  key: K
  value: V
  prev: NodeId
  next: NodeId
}

pub struct LruCache[K, V] {
  capacity: Int
  map: Map[K, NodeId]
  nodes: Array[Option[Node[K, V]]] // Node storage
  head_id: NodeId // Index of dummy head
  tail_id: NodeId // Index of dummy tail
  count: Int      // Current number of items
  free_node_ids: Array[NodeId] // Stack of available indices in `nodes`
}

// Constructor
pub fn new[K, V](capacity: Int) -> LruCache[K, V] {
  let actual_capacity = if capacity < 0 { 0 } else { capacity };
  let total_slots = actual_capacity + 2; // +2 for dummy head and tail

  let mut nodes_storage = Array::make(total_slots, None);

  let head_id: NodeId = 0;
  let tail_id: NodeId = 1;

  // Initialize dummy head node
  nodes_storage[head_id] = Some(Node {
    key: none!(), value: none!(), prev: head_id, next: tail_id,
  });

  // Initialize dummy tail node
  nodes_storage[tail_id] = Some(Node {
    key: none!(), value: none!(), prev: head_id, next: tail_id,
  });
  
  let mut free_ids = Array::empty();
  for i = 2; i < total_slots; i = i + 1 {
    free_ids.push(i);
  }
  // To make pop return lowest index first, if desired (not strictly necessary)
  // free_ids.reverse(); 

  LruCache {
    capacity: actual_capacity,
    map: Map::new(),
    nodes: nodes_storage,
    head_id,
    tail_id,
    count: 0,
    free_node_ids: free_ids,
  }
}

fn get_free_node_id[K, V](cache:   LruCache[K, V]) -> Option[NodeId] {
  cache.free_node_ids.pop()
}

fn release_node_id[K, V](cache:   LruCache[K, V], node_id: NodeId) {
  cache.nodes[node_id] = None; // Clear the slot in the main storage
  cache.free_node_ids.push(node_id); // Add index to free list
}

fn detach[K, V](cache:   LruCache[K, V], node_id: NodeId) {
  let (prev_id, next_id) = match cache.nodes[node_id] {
    Some(ref node_val) => (node_val.prev, node_val.next),
    None => return, 
  };

  if let Some(mut prev_node_val) = cache.nodes[prev_id].take() {
    prev_node_val.next = next_id;
    cache.nodes[prev_id] = Some(prev_node_val);
  }

  if let Some(mut next_node_val) = cache.nodes[next_id].take() {
    next_node_val.prev = prev_id;
    cache.nodes[next_id] = Some(next_node_val);
  }
}

fn attach_to_head[K, V](cache:   LruCache[K, V], node_id: NodeId) {
  let head_actual_next_id = match cache.nodes[cache.head_id] {
      Some(ref head_node_val) => head_node_val.next,
      None => return, // Should not happen for dummy head
  };

  // Update the new node's links
  if let Some(mut current_node_val) = cache.nodes[node_id].take() {
    current_node_val.prev = cache.head_id;
    current_node_val.next = head_actual_next_id;
    cache.nodes[node_id] = Some(current_node_val);
  }

  // Update dummy head's next link
  if let Some(mut head_node_val) = cache.nodes[cache.head_id].take() {
    head_node_val.next = node_id;
    cache.nodes[cache.head_id] = Some(head_node_val);
  }
  
  // Update the old first node's prev link
  if let Some(mut old_first_node_val) = cache.nodes[head_actual_next_id].take() {
    old_first_node_val.prev = node_id;
    cache.nodes[head_actual_next_id] = Some(old_first_node_val);
  }
}

pub fn get[K: Hash + Eq + Clone, V: Clone](cache:   LruCache[K, V>, key: K) -> Option[V] {
  // Use key.clone() if map.get expects owned key or if K is not Copy
  // Assuming map.get can use a reference or K is Copy for lookup.
  // If K needs to be cloned for lookup: cache.map.get(key.clone())
  let node_id_opt = cache.map.get(key); // Assuming K is implicitly clonable or map.get handles it

  match node_id_opt {
    Some(node_id_val) => { // map.get returns Option[NodeId], not Option[&NodeId]
      let node_id = node_id_val; // If it was &NodeId, it would be *node_id_val
      detach(cache, node_id);
      attach_to_head(cache, node_id);
      match cache.nodes[node_id] {
        Some(ref node_val) => Some(node_val.value.clone()),
        None => None, 
      }
    }
    None => None,
  }
}

pub fn put[K: Hash + Eq + Clone, V: Clone](cache:   LruCache[K, V>, key: K, value: V) {
  if cache.capacity == 0 { return; }

  // Use key.clone() for map lookup as key might be moved later if it's a new entry.
  let map_lookup_key = key.clone();
  if let Some(node_id_val) = cache.map.get(map_lookup_key) {
    let node_id = node_id_val;
    if let Some(mut node_val) = cache.nodes[node_id].take() {
        node_val.value = value; // V needs to be Clone if value is not moved
        cache.nodes[node_id] = Some(node_val);
    }
    detach(cache, node_id);
    attach_to_head(cache, node_id);
  } else {
    // Key not in map, insert new node
    if cache.count == cache.capacity {
      let lru_node_id = match cache.nodes[cache.tail_id] {
          Some(ref tail_node_val) => tail_node_val.prev,
          None => return, // Should not happen
      };
      
      if lru_node_id != cache.head_id { // Do not remove dummy head
        let key_to_remove = match cache.nodes[lru_node_id] {
            Some(ref lru_node_val) => lru_node_val.key.clone(), // K must be Clone
            None => return, // Should not happen
        };
        cache.map.remove(key_to_remove);
        detach(cache, lru_node_id);
        release_node_id(cache, lru_node_id);
        cache.count = cache.count - 1;
      }
    }

    match get_free_node_id(cache) {
      Some(new_node_id) => {
        // key is already cloned as map_lookup_key, or use key.clone() again if needed
        // value is moved here
        cache.nodes[new_node_id] = Some(Node {
          key: key.clone(), // Store a clone of the key
          value: value,    // Value is moved
          prev: cache.head_id, // Placeholder, will be set by attach_to_head
          next: cache.tail_id, // Placeholder, will be set by attach_to_head
        });
        attach_to_head(cache, new_node_id);
        cache.map.insert(key, new_node_id); // Original key is moved/cloned into map
        cache.count = cache.count + 1;
      }
      None => {
        // No free slots, should not happen if capacity > 0 and eviction works
        // Or if capacity is 0 and we tried to add.
      }
    }
  }
}

fn main -> Unit {
  var cache: LruCache[String, Int] = new(2);

  put(  cache, "apple".to_string(), 1);
  put(  cache, "banana".to_string(), 2);

  println("get apple = ${get(  cache, "apple".to_string())}");

  put(  cache, "cherry".to_string(), 3);
  println("get banana = ${get(  cache, "banana".to_string())}");

  println("get apple = ${get(  cache, "apple".to_string())}");
  println("get cherry = ${get(  cache, "cherry".to_string())}");
}

test "lru cache basic operations" -> Result[Unit, String] {
  var cache: LruCache[String, Int] = new(2);
  put(  cache, "x".to_string(), 10);
  put(  cache, "y".to_string(), 20);

  debug::assert_eq(get(  cache, "x".to_string()), Some(10))?;
  debug::assert_eq(get(  cache, "y".to_string()), Some(20))?;

  debug::assert_eq(get(  cache, "x".to_string()), Some(10))?; // x is now MRU

  put(  cache, "z".to_string(), 30); // Evicts y
  debug::assert_eq(get(  cache, "y".to_string()), None)?;
  debug::assert_eq(get(  cache, "x".to_string()), Some(10))?;
  debug::assert_eq(get(  cache, "z".to_string()), Some(30))?;
  Ok(())
}

test "lru cache eviction policy" -> Result[Unit, String] {
  var cache: LruCache[String, Int] = new(1);
  put(  cache, "a".to_string(), 100);
  debug::assert_eq(get(  cache, "a".to_string()), Some(100))?;
  put(  cache, "b".to_string(), 200); // Evicts a
  debug::assert_eq(get(  cache, "a".to_string()), None)?;
  debug::assert_eq(get(  cache, "b".to_string()), Some(200))?;
  Ok(())
}