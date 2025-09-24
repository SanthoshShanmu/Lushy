const axios = require('axios');

async function testUsageEndpoint() {
    try {
        console.log('Testing usage-entries endpoint...');
        const response = await axios.post('http://localhost:5001/api/users/test-user-id/products/test-product-id/usage-entries', {
            usageType: 'check_in',
            usageAmount: 1
        }, {
            headers: {
                'Content-Type': 'application/json'
            }
        });
        
        console.log('✅ Usage entries endpoint working!');
        console.log('Status:', response.status);
        console.log('Response:', response.data);
    } catch (error) {
        console.log('❌ Usage entries endpoint failed:');
        console.log('Status:', error.response?.status);
        console.log('Error code:', error.code);
        console.log('Message:', error.response?.data || error.message);
        console.log('Full error:', error.toString());
    }
}

async function testJourneyEndpoint() {
    try {
        console.log('\nTesting journey-events endpoint...');
        const response = await axios.post('http://localhost:5001/api/users/test-user-id/products/test-product-id/journey-events', {
            eventType: 'usage',
            text: 'Test event',
            title: 'Test Title',
            rating: 0
        }, {
            headers: {
                'Content-Type': 'application/json'
            }
        });
        
        console.log('✅ Journey events endpoint working!');
        console.log('Status:', response.status);
        console.log('Response:', response.data);
    } catch (error) {
        console.log('❌ Journey events endpoint failed:');
        console.log('Status:', error.response?.status);
        console.log('Error code:', error.code);
        console.log('Message:', error.response?.data || error.message);
        console.log('Full error:', error.toString());
    }
}

async function testBasicAPI() {
    try {
        console.log('Testing basic API endpoint...');
        const response = await axios.get('http://localhost:5001/api');
        console.log('✅ Basic API working!');
        console.log('Status:', response.status);
        console.log('Response:', response.data);
    } catch (error) {
        console.log('❌ Basic API failed:');
        console.log('Status:', error.response?.status);
        console.log('Error code:', error.code);
        console.log('Message:', error.response?.data || error.message);
        console.log('Full error:', error.toString());
    }
}

async function main() {
    console.log('🧪 Testing Lushy Backend API...\n');
    
    await testBasicAPI();
    await testUsageEndpoint();
    await testJourneyEndpoint();
    
    console.log('\n🏁 Test complete!');
}

main().catch(console.error);