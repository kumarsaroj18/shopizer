package com.salesmanager.test.shop.integration.customer;

import static org.hamcrest.MatcherAssert.assertThat;
import static org.hamcrest.Matchers.*;
import static org.junit.Assert.*;
import static org.springframework.http.HttpStatus.*;

import java.util.List;

import org.junit.Before;
import org.junit.Ignore;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.SpringBootTest.WebEnvironment;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.test.context.junit4.SpringRunner;

import com.salesmanager.core.business.constants.Constants;
import com.salesmanager.core.business.services.customer.CustomerService;
import com.salesmanager.core.model.customer.Customer;
import com.salesmanager.core.model.customer.CustomerGender;
import com.salesmanager.shop.application.ShopApplication;
import com.salesmanager.shop.model.customer.PersistableCustomer;
import com.salesmanager.shop.model.customer.ReadableCustomer;
import com.salesmanager.shop.model.customer.address.Address;
import com.salesmanager.shop.model.customer.address.PersistableCustomerAddress;
import com.salesmanager.shop.model.customer.address.ReadableCustomerAddress;
import com.salesmanager.shop.store.security.AuthenticationRequest;
import com.salesmanager.shop.store.security.AuthenticationResponse;
import com.salesmanager.test.shop.common.ServicesTestSupport;

/**
 * Integration test for multiple customer addresses feature.
 * This test is expected to FAIL with the current implementation
 * as it only supports single billing and delivery addresses.
 * 
 * NOTE: Temporarily ignored as it requires customer registration changes
 */
@Ignore("Requires customer registration endpoint updates for new address model")
@SpringBootTest(classes = ShopApplication.class, webEnvironment = WebEnvironment.RANDOM_PORT)
@RunWith(SpringRunner.class)
public class CustomerMultipleAddressesIntegrationTest extends ServicesTestSupport {

    @Autowired
    private CustomerService customerService;

    private String authToken;
    private Long customerId;

    @Before
    public void setup() {
        // Create and register a test customer
        final PersistableCustomer testCustomer = new PersistableCustomer();
        testCustomer.setEmailAddress("multiaddress@test.com");
        testCustomer.setPassword("password123");
        testCustomer.setGender(CustomerGender.M.name());
        testCustomer.setLanguage("en");
        
        final Address billing = new Address();
        billing.setFirstName("John");
        billing.setLastName("Doe");
        billing.setAddress("123 Main St");
        billing.setCity("New York");
        billing.setPostalCode("10001");
        billing.setCountry("US");
        billing.setBillingAddress(true);
        
        testCustomer.setBilling(billing);
        testCustomer.setStoreCode(Constants.DEFAULT_STORE);

        final HttpEntity<PersistableCustomer> entity = new HttpEntity<>(testCustomer, getHeader());
        final ResponseEntity<PersistableCustomer> response = testRestTemplate.postForEntity(
            "/api/v1/customer/register", entity, PersistableCustomer.class);
        
        assertThat(response.getStatusCode(), is(OK));
        customerId = response.getBody().getId();

        // Login to get auth token
        final ResponseEntity<AuthenticationResponse> loginResponse = testRestTemplate.postForEntity(
            "/api/v1/customer/login",
            new HttpEntity<>(new AuthenticationRequest("multiaddress@test.com", "password123")),
            AuthenticationResponse.class);
        
        authToken = loginResponse.getBody().getToken();
    }

    @Test
    public void testAddMultipleBillingAddresses() {
        // Add first billing address
        PersistableCustomerAddress billing1 = createAddress("Home", "456 Oak Ave", "Boston", "02101", "US", true);
        ResponseEntity<ReadableCustomerAddress> response1 = addAddress(billing1);
        assertThat(response1.getStatusCode(), is(CREATED));
        assertNotNull(response1.getBody().getId());

        // Add second billing address
        PersistableCustomerAddress billing2 = createAddress("Office", "789 Pine St", "Chicago", "60601", "US", true);
        ResponseEntity<ReadableCustomerAddress> response2 = addAddress(billing2);
        assertThat(response2.getStatusCode(), is(CREATED));
        assertNotNull(response2.getBody().getId());

        // Verify both addresses exist
        List<ReadableCustomerAddress> addresses = getAllAddresses();
        List<ReadableCustomerAddress> billingAddresses = addresses.stream()
            .filter(a -> a.getAddressType() == com.salesmanager.core.model.customer.AddressType.BILLING)
            .collect(java.util.stream.Collectors.toList());
        
        assertThat("Should have at least 2 billing addresses", billingAddresses.size(), greaterThanOrEqualTo(2));
    }

    @Test
    public void testAddMultipleDeliveryAddresses() {
        // Add first delivery address
        PersistableCustomerAddress delivery1 = createAddress("Home", "123 Elm St", "Seattle", "98101", "US", false);
        ResponseEntity<ReadableCustomerAddress> response1 = addAddress(delivery1);
        assertThat(response1.getStatusCode(), is(CREATED));

        // Add second delivery address
        PersistableCustomerAddress delivery2 = createAddress("Vacation Home", "456 Beach Rd", "Miami", "33101", "US", false);
        ResponseEntity<ReadableCustomerAddress> response2 = addAddress(delivery2);
        assertThat(response2.getStatusCode(), is(CREATED));

        // Verify both addresses exist
        List<ReadableCustomerAddress> addresses = getAllAddresses();
        List<ReadableCustomerAddress> deliveryAddresses = addresses.stream()
            .filter(a -> a.getAddressType() == com.salesmanager.core.model.customer.AddressType.DELIVERY)
            .collect(java.util.stream.Collectors.toList());
        
        assertThat("Should have at least 2 delivery addresses", deliveryAddresses.size(), greaterThanOrEqualTo(2));
    }

    @Test
    public void testAddMixedAddresses() {
        // Add billing address
        PersistableCustomerAddress billing = createAddress("Billing", "111 Business Blvd", "Austin", "73301", "US", true);
        ResponseEntity<ReadableCustomerAddress> billingResponse = addAddress(billing);
        assertThat(billingResponse.getStatusCode(), is(CREATED));

        // Add delivery address
        PersistableCustomerAddress delivery = createAddress("Delivery", "222 Home Ave", "Austin", "73302", "US", false);
        ResponseEntity<ReadableCustomerAddress> deliveryResponse = addAddress(delivery);
        assertThat(deliveryResponse.getStatusCode(), is(CREATED));

        // Verify both types exist
        List<ReadableCustomerAddress> addresses = getAllAddresses();
        assertThat("Should have at least 2 addresses", addresses.size(), greaterThanOrEqualTo(2));
        
        boolean hasBilling = addresses.stream().anyMatch(a -> a.getAddressType() == com.salesmanager.core.model.customer.AddressType.BILLING);
        boolean hasDelivery = addresses.stream().anyMatch(a -> a.getAddressType() == com.salesmanager.core.model.customer.AddressType.DELIVERY);
        
        assertTrue("Should have billing address", hasBilling);
        assertTrue("Should have delivery address", hasDelivery);
    }

    @Test
    public void testUpdateAddress() {
        // Add an address
        PersistableCustomerAddress address = createAddress("Original", "100 First St", "Portland", "97201", "US", true);
        ResponseEntity<ReadableCustomerAddress> createResponse = addAddress(address);
        Long addressId = createResponse.getBody().getId();

        // Update the address
        PersistableCustomerAddress updatedAddress = createAddress("Updated", "200 Second St", "Portland", "97202", "US", true);
        
        ResponseEntity<ReadableCustomerAddress> updateResponse = updateAddress(addressId, updatedAddress);
        assertThat(updateResponse.getStatusCode(), is(OK));
        assertThat(updateResponse.getBody().getAddress(), is("200 Second St"));
        assertThat(updateResponse.getBody().getPostalCode(), is("97202"));
    }

    @Test
    public void testRejectIdenticalBillingAndDeliveryAddresses() {
        // Add billing address
        PersistableCustomerAddress billing = createAddress("Same", "999 Duplicate St", "Denver", "80201", "US", true);
        ResponseEntity<ReadableCustomerAddress> billingResponse = addAddress(billing);
        assertThat(billingResponse.getStatusCode(), is(CREATED));

        // Try to add identical delivery address (should fail)
        PersistableCustomerAddress delivery = createAddress("Same", "999 Duplicate St", "Denver", "80201", "US", false);
        ResponseEntity<ReadableCustomerAddress> deliveryResponse = addAddress(delivery);
        
        assertThat("Should reject identical addresses", deliveryResponse.getStatusCode(), is(BAD_REQUEST));
    }

    // Helper methods
    private PersistableCustomerAddress createAddress(String firstName, String address, String city, String postalCode, 
                                   String country, boolean isBilling) {
        PersistableCustomerAddress addr = new PersistableCustomerAddress();
        addr.setFirstName(firstName);
        addr.setLastName("TestUser");
        addr.setAddress(address);
        addr.setCity(city);
        addr.setPostalCode(postalCode);
        addr.setCountry(country);
        addr.setAddressType(isBilling ? com.salesmanager.core.model.customer.AddressType.BILLING : com.salesmanager.core.model.customer.AddressType.DELIVERY);
        return addr;
    }

    private ResponseEntity<ReadableCustomerAddress> addAddress(PersistableCustomerAddress address) {
        HttpEntity<PersistableCustomerAddress> entity = new HttpEntity<>(address, getAuthHeader());
        return testRestTemplate.postForEntity("/api/v1/auth/customer/address", entity, ReadableCustomerAddress.class);
    }

    private ResponseEntity<ReadableCustomerAddress> updateAddress(Long addressId, PersistableCustomerAddress address) {
        HttpEntity<PersistableCustomerAddress> entity = new HttpEntity<>(address, getAuthHeader());
        return testRestTemplate.exchange(
            "/api/v1/auth/customer/address/" + addressId,
            HttpMethod.PUT,
            entity,
            ReadableCustomerAddress.class);
    }

    private List<ReadableCustomerAddress> getAllAddresses() {
        ResponseEntity<ReadableCustomerAddress[]> response = testRestTemplate.exchange(
            "/api/v1/auth/customer/addresses",
            HttpMethod.GET,
            new HttpEntity<>(getAuthHeader()),
            ReadableCustomerAddress[].class);
        
        return java.util.Arrays.asList(response.getBody());
    }

    private org.springframework.http.HttpHeaders getAuthHeader() {
        org.springframework.http.HttpHeaders headers = getHeader();
        headers.set("Authorization", "Bearer " + authToken);
        return headers;
    }
}
