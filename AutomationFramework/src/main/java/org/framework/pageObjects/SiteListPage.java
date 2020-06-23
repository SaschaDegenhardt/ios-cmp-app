package org.framework.pageObjects;

import static org.framework.logger.LoggingManager.logMessage;

import java.time.Duration;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.concurrent.TimeUnit;

import org.framework.enums.PlatformName;
import org.framework.helpers.Page;
import org.openqa.selenium.By;
import org.openqa.selenium.Point;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.support.PageFactory;
import org.openqa.selenium.support.ui.ExpectedConditions;
import org.openqa.selenium.support.ui.WebDriverWait;
import io.appium.java_client.PerformsTouchActions;
import io.appium.java_client.TouchAction;
import io.appium.java_client.touch.WaitOptions;
import io.appium.java_client.touch.offset.PointOption;
import io.appium.java_client.pagefactory.AppiumFieldDecorator;
import io.appium.java_client.pagefactory.WithTimeout;
import io.appium.java_client.pagefactory.iOSXCUITFindBy;

public class SiteListPage extends Page {

	WebDriver driver;

	public SiteListPage(WebDriver driver) throws InterruptedException {
		this.driver = driver;
		PageFactory.initElements(driver, this);
		logMessage("Initializing the " + this.getClass().getSimpleName() + " elements");
		PageFactory.initElements(new AppiumFieldDecorator(driver), this);
		Thread.sleep(1000);
	}

	@iOSXCUITFindBy(accessibility = "Add")
	public WebElement GDPRAddButton;

	@iOSXCUITFindBy(xpath = "//XCUIElementTypeOther[contains(@name, 'Property List')]")
	public WebElement GDPRSiteListPageHeader;

	@iOSXCUITFindBy(xpath = "//XCUIElementTypeStaticText[@name=\'Site List\']")
	public WebElement GDPRSiteListView;

	@iOSXCUITFindBy(xpath = "//XCUIElementTypeButton[@name='Edit']")
	public WebElement GDPREditButton;

	@iOSXCUITFindBy(xpath = "//XCUIElementTypeButton[@name='Reset']")
	public WebElement GDPRResetButton;

	@WithTimeout(time = 30, chronoUnit = ChronoUnit.SECONDS)
	@iOSXCUITFindBy(xpath = "//XCUIElementTypeButton[@name='Trash']")
	public WebElement GDPRDeleteButton;

	@WithTimeout(time = 30, chronoUnit = ChronoUnit.SECONDS)
	@iOSXCUITFindBy(xpath = "(//XCUIElementTypeStaticText[@name=\'propertyCell\'])")
	public List<WebElement> GDPRSiteList;

	@WithTimeout(time = 30, chronoUnit = ChronoUnit.SECONDS)
	@iOSXCUITFindBy(accessibility = "propertyName")
	public WebElement GDPRSiteName;

	@WithTimeout(time = 50, chronoUnit = ChronoUnit.SECONDS)
	@iOSXCUITFindBy(xpath = "(//XCUIElementTypeButton)")
	public List<WebElement> ActionButtons;

	@WithTimeout(time = 50, chronoUnit = ChronoUnit.SECONDS)
	@iOSXCUITFindBy(xpath = "(//XCUIElementTypeStaticText)")
	public List<WebElement> ErrorMessage;

	@iOSXCUITFindBy(accessibility = "YES")
	public WebElement YESButton;

	@iOSXCUITFindBy(accessibility = "NO")
	public WebElement NOButton;

	boolean siteFound = false;

	public boolean isSitePressent_gdpr(String siteName) throws InterruptedException {

		siteFound = false;

		if (driver.findElement(By.xpath("//XCUIElementTypeStaticText[@name='propertyCell']")).getText()
				.equals(siteName)) {
			siteFound = true;
		}
		System.out.println(siteFound);
		return siteFound;
	}

	public void selectAction(String action) throws InterruptedException {
		Thread.sleep(3000);

		// for(WebElement actionButton : ActionButtons) {
		if (action.equalsIgnoreCase("Reset")) {
			ActionButtons.get(1).click();
		} else if (action.equalsIgnoreCase("Edit")) {
			ActionButtons.get(2).click();
		} else if (action.equalsIgnoreCase("Delete")) {
			ActionButtons.get(3).click();
		}
		// }

	}

	public boolean isSitePressent(String siteName) throws InterruptedException {
		return siteFound;

	}

	public void tapOnSite_gdpr(String siteName) throws InterruptedException {
		Thread.sleep(3000);
		driver.findElement(By.xpath("//XCUIElementTypeStaticText[@name='propertyCell']")).click();
	}

	public void swipeHorizontaly_gdpr(String siteName) throws InterruptedException {
		System.out.println("Swipe on " + siteName);
		WebElement aa = (WebElement) driver.findElement(By.xpath("//XCUIElementTypeStaticText[@name='propertyCell']"));

		Point point = aa.getLocation();
		TouchAction action = new TouchAction((PerformsTouchActions) driver);

		int[] rightTopCoordinates = { aa.getLocation().getX() + aa.getSize().getWidth(), aa.getLocation().getY() };
		int[] leftTopCoordinates = { aa.getLocation().getX(), aa.getLocation().getY() };
		action.press(PointOption.point(rightTopCoordinates[0] - 1, rightTopCoordinates[1] + 1))
				.waitAction(WaitOptions.waitOptions(Duration.ofMillis(3000)))
				.moveTo(PointOption.point(leftTopCoordinates[0] + 1, leftTopCoordinates[1] + 1)).release().perform();

		Thread.sleep(8000);
	}

	public void waitForElement(WebElement ele, int timeOutInSeconds) {
		WebDriverWait wait = new WebDriverWait(driver, timeOutInSeconds);
		wait.until(ExpectedConditions.visibilityOf(ele));
	}

	public boolean verifyDeleteSiteMessage(String udid) {
		return ErrorMessage.get(ErrorMessage.size() - 1).getText().contains("Are you sure you want to");

	}

}
