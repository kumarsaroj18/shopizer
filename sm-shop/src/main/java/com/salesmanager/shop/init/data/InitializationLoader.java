package com.salesmanager.shop.init.data;

import javax.annotation.PostConstruct;
import javax.inject.Inject;

import org.apache.commons.lang3.StringUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import com.salesmanager.core.business.constants.SystemConstants;
import com.salesmanager.core.business.exception.ServiceException;
import com.salesmanager.core.business.services.merchant.MerchantStoreService;
import com.salesmanager.core.business.services.content.ContentService;
import com.salesmanager.core.business.services.reference.init.InitializationDatabase;
import com.salesmanager.core.business.services.reference.language.LanguageService;
import com.salesmanager.core.business.services.system.MerchantConfigurationService;
import com.salesmanager.core.business.services.system.SystemConfigurationService;
import com.salesmanager.core.business.services.user.GroupService;
import com.salesmanager.core.business.services.user.PermissionService;
import com.salesmanager.core.business.utils.CoreConfiguration;
import com.salesmanager.core.model.content.Content;
import com.salesmanager.core.model.content.ContentDescription;
import com.salesmanager.core.model.content.ContentType;
import com.salesmanager.core.model.merchant.MerchantStore;
import com.salesmanager.core.model.reference.language.Language;
import com.salesmanager.core.model.system.MerchantConfig;
import com.salesmanager.core.model.system.SystemConfiguration;
import com.salesmanager.shop.admin.security.WebUserServices;
import com.salesmanager.shop.constants.ApplicationConstants;


@Component
public class InitializationLoader {
	
	private static final Logger LOGGER = LoggerFactory.getLogger(InitializationLoader.class);

	@Value("${db.init.data:true}")
    private boolean initDefaultData;

	
	@Inject
	private MerchantConfigurationService merchantConfigurationService;
	
	@Inject
	private InitializationDatabase initializationDatabase;
	
	//@Inject
	//private InitData initData;
	
	@Inject
	private SystemConfigurationService systemConfigurationService;
	
	@Inject
	private WebUserServices userDetailsService;

	@Inject
	protected PermissionService  permissionService;
	
	@Inject
	protected GroupService   groupService;
	
	@Inject
	private CoreConfiguration configuration;
	
	@Inject
	protected MerchantStoreService merchantService;
	
	@Inject
	private ContentService contentService;
	
	@Inject
	private LanguageService languageService;

	
	@PostConstruct
	public void init() {
		
		try {
			
			//Check flag to populate or not the database
			if(!this.initDefaultData) {
				return;
			}
			
			if (initializationDatabase.isEmpty()) {
				

				//All default data to be created
				
				LOGGER.info(String.format("%s : Shopizer database is empty, populate it....", "sm-shop"));
		
				 initializationDatabase.populate("sm-shop");
				
				 MerchantStore store = merchantService.getByCode(MerchantStore.DEFAULT_STORE);

                  userDetailsService.createDefaultAdmin();
                  MerchantConfig config = new MerchantConfig();
				  config.setAllowPurchaseItems(true);
				  config.setDisplayAddToCartOnFeaturedItems(true);
				  
				  merchantConfigurationService.saveMerchantConfig(config, store);


			}
			
			// Ensure default content boxes exist
			ensureDefaultContent();
			
		} catch (Exception e) {
			LOGGER.error("Error in the init method",e);
		}
			
	}
	
	private void ensureDefaultContent() {
		try {
			MerchantStore store = merchantService.getByCode(MerchantStore.DEFAULT_STORE);
			if (store == null) return;
			
			Language en = languageService.getByCode("en");
			if (en == null) return;
			
			Content existing = contentService.getByCode("headerMessage", store, en);
			if (existing == null) {
				Content headerMessage = new Content();
				headerMessage.setCode("headerMessage");
				headerMessage.setMerchantStore(store);
				headerMessage.setContentType(ContentType.BOX);
				headerMessage.setVisible(true);
				
				ContentDescription headerDesc = new ContentDescription();
				headerDesc.setLanguage(en);
				headerDesc.setName("Header Message");
				headerDesc.setDescription("Welcome to our store");
				headerDesc.setContent(headerMessage);
				
				headerMessage.getDescriptions().add(headerDesc);
				contentService.create(headerMessage);
				
				LOGGER.info("Created default headerMessage content box");
			}
		} catch (Exception e) {
			LOGGER.warn("Could not create default content: " + e.getMessage());
		}
	}




}
