package com.salesmanager.shop.store.api.v1.customer;

import java.util.List;

import javax.validation.Valid;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import com.salesmanager.core.model.merchant.MerchantStore;
import com.salesmanager.shop.model.customer.address.PersistableCustomerAddress;
import com.salesmanager.shop.model.customer.address.ReadableCustomerAddress;
import com.salesmanager.shop.store.facade.customer.CustomerAddressFacade;

import io.swagger.annotations.*;
import springfox.documentation.annotations.ApiIgnore;

@RestController
@RequestMapping("/api/v1")
@Api(tags = {"Customer Address Management"})
public class CustomerAddressApi {

    @Autowired
    private CustomerAddressFacade customerAddressFacade;

    @PostMapping("/auth/customer/address")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasRole('AUTH_CUSTOMER')")
    @ApiOperation(value = "Add a new address", response = ReadableCustomerAddress.class)
    @ApiResponses({
        @ApiResponse(code = 201, message = "Address created successfully"),
        @ApiResponse(code = 400, message = "Invalid address data or validation failed"),
        @ApiResponse(code = 401, message = "Unauthorized")
    })
    public ReadableCustomerAddress create(
            @Valid @RequestBody PersistableCustomerAddress address,
            @ApiIgnore @RequestAttribute("CUSTOMER") Long customerId,
            @ApiIgnore MerchantStore merchantStore) {
        return customerAddressFacade.create(address, customerId, merchantStore);
    }

    @PutMapping("/auth/customer/address/{id}")
    @PreAuthorize("hasRole('AUTH_CUSTOMER')")
    @ApiOperation(value = "Update an existing address", response = ReadableCustomerAddress.class)
    @ApiResponses({
        @ApiResponse(code = 200, message = "Address updated successfully"),
        @ApiResponse(code = 400, message = "Invalid address data"),
        @ApiResponse(code = 404, message = "Address not found")
    })
    public ReadableCustomerAddress update(
            @PathVariable Long id,
            @Valid @RequestBody PersistableCustomerAddress address,
            @ApiIgnore @RequestAttribute("CUSTOMER") Long customerId,
            @ApiIgnore MerchantStore merchantStore) {
        return customerAddressFacade.update(id, address, customerId, merchantStore);
    }

    @DeleteMapping("/auth/customer/address/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasRole('AUTH_CUSTOMER')")
    @ApiOperation(value = "Delete an address")
    @ApiResponses({
        @ApiResponse(code = 204, message = "Address deleted successfully"),
        @ApiResponse(code = 404, message = "Address not found")
    })
    public void delete(
            @PathVariable Long id,
            @ApiIgnore @RequestAttribute("CUSTOMER") Long customerId) {
        customerAddressFacade.delete(id, customerId);
    }

    @GetMapping("/auth/customer/address/{id}")
    @PreAuthorize("hasRole('AUTH_CUSTOMER')")
    @ApiOperation(value = "Get address by ID", response = ReadableCustomerAddress.class)
    @ApiResponses({
        @ApiResponse(code = 200, message = "Address found"),
        @ApiResponse(code = 404, message = "Address not found")
    })
    public ReadableCustomerAddress getById(
            @PathVariable Long id,
            @ApiIgnore @RequestAttribute("CUSTOMER") Long customerId) {
        return customerAddressFacade.getById(id, customerId);
    }

    @GetMapping("/auth/customer/addresses")
    @PreAuthorize("hasRole('AUTH_CUSTOMER')")
    @ApiOperation(value = "Get all addresses for logged-in customer", response = ReadableCustomerAddress.class, responseContainer = "List")
    public List<ReadableCustomerAddress> getAll(
            @ApiIgnore @RequestAttribute("CUSTOMER") Long customerId) {
        return customerAddressFacade.getByCustomer(customerId);
    }
}
