const fs = require('fs');
const path = require('path');
const { MongoClient } = require('mongodb');

// Configuración
const MONGO_URI = 'mongodb://127.0.0.1:27017/kn_store_test'; 
const SOURCE_JSON = path.join(__dirname, 'kn_store_test.json');
const OUTPUT_DIR = path.join(__dirname, 'data');

async function importData() {
  let client;
  try {
    console.log(`Leyendo datos originales desde: ${SOURCE_JSON}`);
    const rawData = fs.readFileSync(SOURCE_JSON, 'utf-8');
    const parsedData = JSON.parse(rawData);

    // 1. Extraer todas las tablas en memoria
    const tables = {};
    for (const item of parsedData) {
      if (item.type === 'table') {
        tables[item.name] = item.data || [];
      }
    }

    console.log('Tablas extraídas en memoria. Iniciando estructuración a NoSQL...');

    // 2. Refactorización (Anidación de datos / Embedding)
    
    // a. Categorías (Embeber Subcategorías)
    const subcatsMap = {}; 
    (tables['subcategory'] || []).forEach(sub => {
      if(!subcatsMap[sub.category_id]) subcatsMap[sub.category_id] = [];
      const { category_id, ...cleanSub } = sub;
      subcatsMap[sub.category_id].push(cleanSub);
    });
    const categories = (tables['category'] || []).map(cat => ({
      ...cat,
      subcategories: subcatsMap[cat.id] || []
    }));

    // b. Usuarios (Embeber Direcciones)
    const addressMap = {}; 
    (tables['address'] || []).forEach(addr => {
      if(!addressMap[addr.user_id]) addressMap[addr.user_id] = [];
      const { user_id, ...cleanAddr } = addr;
      addressMap[addr.user_id].push(cleanAddr);
    });
    const users = (tables['users'] || []).map(user => ({
      ...user,
      addresses: addressMap[user.id] || []
    }));

    // c. Órdenes (Embeber Items, Pagos, Facturas y Envíos)
    const itemsMap = {}; 
    (tables['order_item'] || []).forEach(item => {
      if(!itemsMap[item.order_id]) itemsMap[item.order_id] = [];
      const { order_id, ...cleanItem } = item;
      itemsMap[item.order_id].push(cleanItem);
    });
    const billMap = {}; 
    (tables['bill'] || []).forEach(b => { billMap[b.order_id] = b; });
    
    const paymentMap = {};
    (tables['payment'] || []).forEach(p => { paymentMap[p.order_id] = p; });

    const shipmentMap = {};
    (tables['shipment'] || []).forEach(s => { shipmentMap[s.order_id] = s; });

    const flatAddresses = {};
    (tables['address'] || []).forEach(addr => { flatAddresses[addr.id] = addr; });

    const orders = (tables['orders'] || []).map(order => {
      const { address_id, ...otrasProps } = order;
      // Anidamos toda la información dependiente a la órden
      return {
        ...otrasProps,
        shipping_address: flatAddresses[address_id] || null,
        items: itemsMap[order.id] || [],
        payment: paymentMap[order.id] || null,
        bill: billMap[order.id] || null,
        shipment: shipmentMap[order.id] || null
      };
    });

    const products = tables['product'] || [];

    // Colecciones finales listas para MongoDB
    const collectionsToMigrate = [
       { name: 'categories', data: categories },
       { name: 'users', data: users },
       { name: 'orders', data: orders },
       { name: 'products', data: products }
    ];

    // 3. Crear subcarpetas organizadas y guardar JSON locales
    console.log('Guardando datos refactorizados en subcarpetas...');
    if (!fs.existsSync(OUTPUT_DIR)) {
      fs.mkdirSync(OUTPUT_DIR, { recursive: true });
    }

    for (const col of collectionsToMigrate) {
        if (col.data.length === 0) continue;

        const folderPath = path.join(OUTPUT_DIR, col.name);
        if (!fs.existsSync(folderPath)) {
          fs.mkdirSync(folderPath, { recursive: true });
        }
        
        const filePath = path.join(folderPath, `${col.name}.json`);
        fs.writeFileSync(filePath, JSON.stringify(col.data, null, 2));
        console.log(`✅ Archivo exportado: ${filePath}`);
    }

    // 4. Conectar a MongoDB e insertar colecciones optimizadas
    console.log(`\nConectando a MongoDB en: ${MONGO_URI}`);
    client = new MongoClient(MONGO_URI);
    await client.connect();
    const db = client.db();
    console.log('Conexión exitosa a MongoDB.');

    for (const col of collectionsToMigrate) {
        if (col.data.length === 0) continue;
        
        // Limpiamos datos previos de la colección y luego insertamos
        await db.collection(col.name).deleteMany({});
        const result = await db.collection(col.name).insertMany(col.data);
        console.log(`🚀 Colección '${col.name}': ${result.insertedCount} documentos insertados.`);
    }

    console.log('\n🎉 Proceso unificado completado con éxito.');

  } catch (error) {
    console.error('❌ Ocurrió un error en el proceso:', error);
  } finally {
    if (client) {
      await client.close();
      console.log('🔌 Conexión a MongoDB cerrada.');
    }
  }
}

importData();
